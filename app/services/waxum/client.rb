require "base64"

module Waxum
  # Adapter fino para o gateway Waxum (WhatsApp, self-hosted, ver
  # docker-compose-production.yml). Uma instância por sessão (= um WhatsApp
  # conectado). Toda a API fica sob /api/v1/sessions/{session}.
  #
  # Ids de conversa: o app guarda "5511...@c.us"; o Waxum fala
  # "5511...@s.whatsapp.net" (ou "...@lid"). `jid` converte.
  class Client
    # Eventos de webhook que o app consome (ver Webhook::WaxumController).
    WEBHOOK_EVENTS = %w[message connected disconnected logged_out qr_code pair_code client_outdated].freeze

    def self.base_url
      ENV.fetch("WAXUM_URL", "http://waxum:3451")
    end

    def self.webhook_url
      ENV.fetch("WAXUM_WEBHOOK_URL", "https://escrevezap.com.br/webhook/waxum")
    end

    def self.webhook_secret
      ENV.fetch("WAXUM_WEBHOOK_SECRET")
    end

    # "5511...@c.us" → "5511...@s.whatsapp.net"; "@lid"/"@s.whatsapp.net"
    # ficam como estão, sem o sufixo de aparelho (":12").
    def self.jid(chat_id)
      user, server = chat_id.to_s.split("@", 2)
      user = user.to_s.split(":").first
      server = "s.whatsapp.net" if server.blank? || server == "c.us"
      "#{user}@#{server}"
    end

    def initialize(session:)
      @session = session
      @api = ApiRequest.new(self.class.base_url, { "Authorization" => "Bearer #{ENV.fetch('WAXUM_TOKEN')}" })
    end

    # ── Sessão ──────────────────────────────────────────────────────────

    # { "id", "status", "phone_number", "push_name", ... } ou nil (404)
    def session_info
      @api.get(path)
    rescue ApiRequest::ApiClientError => e
      raise unless e.message.include?(" 404 ")

      nil
    end

    # Estado ao vivo: { "status", "is_logged_in", "socket_alive", ... }.
    # Mais confiável que session_info, que só é atualizado no evento connected.
    def status
      @api.get(path("/status"))
    end

    # Conta conectada: { "phone_number" => "5585...", "name" => "...", ... }
    def profile
      @api.get(path("/profile"))
    end

    def create_session
      @api.post("/api/v1/sessions", { id: @session, name: @session })
    end

    # 409: já conectada.
    def connect
      @api.post(path("/connect"), { device: nil })
    rescue ApiRequest::ApiClientError => e
      raise unless e.message.include?(" 409 ")
    end

    def disconnect
      @api.post(path("/disconnect"))
    end

    # Apaga a sessão e as chaves do aparelho (desvincula do celular).
    def delete_session
      @api.post(path("/logout")) rescue nil
      @api.delete(path)
    rescue ApiRequest::ApiClientError => e
      raise unless e.message.include?(" 404 ")
    end

    # Código de 8 letras para "Conectar com número de telefone". 409 = já logada.
    def pair(phone_number)
      @api.post(path("/pair"), { phone_number: phone_number })["code"]
    end

    # Registra o webhook do app na sessão (um por URL; sem edição, então
    # apaga e recria se os eventos mudaram).
    def ensure_webhook!
      existing = Array(@api.get(path("/webhooks"))["webhooks"]).find { |w| w["url"] == self.class.webhook_url }
      return if existing && existing["events"].to_a.sort == WEBHOOK_EVENTS.sort

      @api.delete(path("/webhooks/#{existing['id']}")) if existing
      @api.post(path("/webhooks"), { url: self.class.webhook_url, events: WEBHOOK_EVENTS, secret: self.class.webhook_secret })
    end

    # ── Mensagens ───────────────────────────────────────────────────────

    # Devolve o id da mensagem enviada (gerado pelo Waxum).
    def send_text(to:, text:, reply_to: nil)
      body = { to: self.class.jid(to), text: text }
      body[:reply_to] = reply_to if reply_to.present?
      @api.post(path("/messages/text"), body)["message_id"]
    end

    def edit_message(to:, message_id:, text:)
      @api.post(path("/messages/edit"), { to: self.class.jid(to), message_id: message_id, text: text })
    end

    def mark_read(chat:, message_ids:)
      @api.post(path("/messages/read"), { chat_jid: self.class.jid(chat), message_ids: Array(message_ids) })
    end

    # media: chaves do webhook (direct_path, media_key, file_sha256,
    # file_enc_sha256, file_length). Devolve os bytes do arquivo.
    def download_media(media, media_type: "audio")
      response = @api.post(path("/media/download"), {
        direct_path:     media["direct_path"],
        media_key:       media["media_key"],
        file_sha256:     media["file_sha256"],
        file_enc_sha256: media["file_enc_sha256"],
        file_length:     media["file_length"].to_i,
        media_type:      media_type
      })
      Base64.decode64(response["data"])
    end

    # Chaves da mídia de uma mensagem guardada pelo Waxum (mesmo formato de
    # data.media no webhook), ou nil. Cobre mensagens que chegaram antes da
    # conexão (sincronização do histórico) e nunca vieram pelo webhook.
    def stored_media(chat:, message_id:)
      jid = ERB::Util.url_encode(self.class.jid(chat))
      media = @api.get(path("/store/chats/#{jid}/messages/#{ERB::Util.url_encode(message_id)}/media"))
      media.is_a?(Hash) ? media : nil
    rescue ApiRequest::ApiClientError
      nil
    end

    # ── Contatos ────────────────────────────────────────────────────────

    def profile_picture_url(chat_id)
      @api.get(path("/contacts/#{ERB::Util.url_encode(self.class.jid(chat_id))}/picture"))["url"]
    rescue ApiRequest::ApiClientError
      nil
    end

    # [{ "jid", "phone", "full_name", "push_name", ... }]
    def contacts(limit: 1000)
      Array(@api.get(path("/contacts"), { limit: limit })["contacts"])
    end

    private

    def path(suffix = "")
      "/api/v1/sessions/#{@session}#{suffix}"
    end
  end
end
