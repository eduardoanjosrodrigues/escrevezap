module ExternalEvents
  module WhatsappParsers
    # Webhook do Waxum: { session_id, event, timestamp, data }. Traduz para o
    # formato que o WhatsappProcessor consome:
    #   session.status   → { status: <WahaSession.waha_status> }
    #   message          → áudio, com as chaves da mídia
    #   message.reaction → reação a uma mensagem (reply_to_id = a reagida)
    class WaxumParser < Base
      # disconnected é queda de socket: o Waxum reconecta sozinho, então vira
      # starting (o WahaSessionDisconnectCheckJob decide se avisa o usuário).
      STATUSES = {
        "connected"    => "working",
        "disconnected" => "starting",
        "logged_out"   => "failed",
        "qr_code"      => "scan_qr_code",
        "pair_code"    => "scan_qr_code"
      }.freeze

      def parse
        event = @raw_data[:event].to_s
        data  = @raw_data[:data] || {}

        parsed = if STATUSES.key?(event) || event == "client_outdated"
          { event: "session.status", payload: { status: STATUSES[event], raw_event: event } }
        elsif event == "message" && data[:message_type] == "reaction"
          { event: "message.reaction", payload: reaction_payload(data) }
        elsif event == "message"
          { event: "message", payload: message_payload(data) }
        else
          { event: event, payload: {} }
        end

        parsed.merge(session: @raw_data[:session_id])
      end

      private

      def message_payload(data)
        media = data[:media] || {}

        {
          message_id: data[:message_id],
          chat_jid:   Waxum::Client.jid(data[:chat]),
          phone:      phone_of(data[:chat], data[:chat_phone]),
          fromMe:     data[:is_from_me] == true,
          hasMedia:   media.present?,
          media:      media.slice(:direct_path, :media_key, :file_sha256, :file_enc_sha256, :file_length, :seconds)
                           .merge(mimetype: media[:mimetype] || data[:media_mimetype])
        }
      end

      def reaction_payload(data)
        reaction = data[:reaction] || {}

        {
          chat_jid:    Waxum::Client.jid(data[:chat]),
          phone:       phone_of(data[:chat], data[:chat_phone]),
          fromMe:      data[:is_from_me] == true,
          body:        reaction[:emoji] || data[:text],
          reply_to_id: reaction[:message_id]
        }
      end

      # chat_phone vem resolvido pelo Waxum quando a conversa é @lid.
      def phone_of(chat, chat_phone)
        chat_phone.presence || chat.to_s.split("@").first.to_s.split(":").first
      end
    end
  end
end
