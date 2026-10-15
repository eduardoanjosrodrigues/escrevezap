class WahaSession < ApplicationRecord
  belongs_to :user
  has_many :monitored_contacts, dependent: :destroy
  has_many :transcriptions, through: :monitored_contacts
  has_many :waha_session_events, dependent: :destroy

  enum :waha_status, {
    pending:      "pending",      # session not yet created in Waha
    stopped:      "stopped",
    starting:     "starting",
    scan_qr_code: "scan_qr_code",
    working:      "working",
    failed:       "failed"
  }, default: :pending

  # When set to anything other than :never, audios from unknown contacts are
  # transcribed automatically (no MonitoredContact needed). Direction mirrors
  # the same semantics as MonitoredContact#direction.
  enum :auto_transcribe, {
    never:    "never",
    incoming: "incoming",
    outgoing: "outgoing",
    both:     "both"
  }, default: :never, prefix: :auto_transcribe

  # How the user chooses which audios get transcribed.
  #   :reaction           → user reacts with any emoji on a message; the bot replies
  #                         in the conversation. No manual contact list needed.
  #   :monitored_contacts → only audios from contacts listed in monitored_contacts
  #                         are transcribed (legacy flow).
  enum :transcription_mode, {
    reaction:           "reaction",
    monitored_contacts: "monitored_contacts"
  }, default: :reaction, prefix: :mode

  validates :session_name, presence: true, uniqueness: true
  before_validation :set_session_name, on: :create

  after_update_commit :broadcast_status_change,        if: :saved_change_to_waha_status?
  after_update_commit :schedule_disconnect_check,      if: :saved_change_to_waha_status?
  after_update_commit :schedule_pairing_code_expired_notice, if: :saved_change_to_waha_status?
  after_update_commit :fetch_profile_picture,          if: :saved_change_to_waha_status?
  after_update_commit :complete_user_onboarding,       if: :saved_change_to_waha_status?
  after_update_commit :record_status_event,            if: :saved_change_to_waha_status?

  # Finds (or creates, along with a new User) the WahaSession that anchors a
  # given phone number's identity. Used both by the connected-flow webhook and
  # by the direct-chat-with-the-bot flow (Meta), so a user always maps to a
  # single WahaSession/quota pool regardless of which channel they use.
  def self.find_or_create_for_phone!(phone:, display_name: nil)
    session = find_or_initialize_by(waha_chat_id: "#{phone}@c.us")

    if session.new_record?
      session.user = User.create!(
        name:     display_name.presence || "Novo usuário",
        provider: :phone,
        uid:      phone
      )
      session.save!
    end

    session
  end

  # Convenience shortcut for building API calls
  def waha_client
    Waha::Client.new(session: session_name)
  end

  # Create (or restart) the Waha session and mark as starting.
  def connect!
    waha_client.sessions.create
    update!(waha_status: :starting)
  rescue => e
    update!(waha_status: :failed)
    raise e
  end

  # Stop the Waha session gracefully.
  def disconnect!
    waha_client.sessions.stop
    update!(waha_status: :stopped)
  rescue => e
    Rails.logger.warn "[WahaSession#disconnect!] #{e.message}"
    Sentry.capture_exception(e)
  end

  # Requests a pairing code from WAHA for the given phone number.
  # Handles starting/connecting the session if not running.
  def request_pairing_code(phone_number)
    phone = phone_number.to_s.gsub(/\D/, "")
    raise "Número de telefone inválido" if phone.blank?

    # Confere o status real no Waha: o waha_status local pode estar desatualizado
    # (ex.: sessão FAILED no Waha e scan_qr_code aqui), e o Waha só aceita pedir
    # código em SCAN_QR_CODE.
    live_status = (waha_client.sessions.get rescue nil)&.dig("status")

    unless live_status == "SCAN_QR_CODE"
      begin
        waha_client.sessions.restart
        update!(waha_status: :starting)
      rescue => e
        if missing_waha_session_error?(e)
          connect!
        else
          raise e
        end
      end

      # Wait up to 15 seconds for the session to reach scan_qr_code state
      15.times do
        session_info = waha_client.sessions.get rescue nil
        if session_info && session_info["status"] == "SCAN_QR_CODE"
          update!(waha_status: :scan_qr_code)
          break
        end
        sleep 1
      end
    end

    result = waha_client.sessions.request_pairing_code(phone_number: phone)
    result["code"]
  rescue => e
    Rails.logger.error "[WahaSession#request_pairing_code] Error requesting pairing code: #{e.class} #{e.message}"
    raise e
  end

  def missing_waha_session_error?(error)
    [error, error.cause].compact.any? do |err|
      next false unless err.is_a?(ApiRequest::ApiClientError)

      message = err.message.to_s.downcase
      has_404 = message.include?(" 404 ") || message.include?("404")
      missing_session = message.include?("session") && (
        message.include?("not found") ||
        message.include?("does not exist") ||
        message.include?("unknown")
      )

      has_404 || missing_session
    end
  end

  # Transcriptions that count toward this month's quota. Failed ones don't, and
  # neither do ones stuck in processing for over an hour (abandoned jobs).
  # `excluding` leaves out the transcription whose quota is being checked, so
  # the 20th audio of a 20/month plan still goes through.
  def monthly_transcriptions(excluding: nil)
    scope = transcriptions.this_month
                          .where.not(status: :failed)
                          .where("transcriptions.status <> 'processing' OR transcriptions.created_at > ?", 1.hour.ago)
    excluding ? scope.where.not(id: excluding.id) : scope
  end

  def monthly_transcription_count(excluding: nil)
    monthly_transcriptions(excluding: excluding).count
  end

  private

  def set_session_name
    self.session_name ||= "user_#{user_id}"
  end

  def broadcast_status_change
    ActionCable.server.broadcast("waha_session_status_user_#{user_id}", { status: waha_status })
  end

  def schedule_disconnect_check
    old_status, new_status = saved_change_to_waha_status
    return unless old_status == "working" && new_status != "working"

    WahaSessionDisconnectCheckJob.set(wait: 1.minute).perform_later(id)
  end

  # O código de pareamento expira em ~2min40 e o WAHA leva a sessão para failed.
  # O job decide se o usuário pediu esse código (e por isso deve ser avisado).
  def schedule_pairing_code_expired_notice
    old_status, new_status = saved_change_to_waha_status
    return unless old_status == "scan_qr_code" && new_status == "failed"

    PairingCodeExpiredNoticeJob.perform_later(id)
  end

  def fetch_profile_picture
    _old, new_status = saved_change_to_waha_status
    return unless new_status == "working"
    return if display_name.present?

    FetchWahaSessionProfileJob.perform_later(id)
  end

  def complete_user_onboarding
    old_status, new_status = saved_change_to_waha_status
    return unless new_status == "working"

    # Only greet on an actual pairing (QR/pairing code accepted). WAHA routinely
    # bounces healthy sessions working -> starting -> working, and greeting on
    # those reconnects spammed users with the same message several times a day.
    if old_status == "scan_qr_code" && user.provider == "phone" && waha_chat_id.present?
      recipient_phone = waha_chat_id.split("@").first
      meta_service = Meta::Service.new(recipient: recipient_phone)

      meta_service.send_message(
        "🎉 *Oba! Seu WhatsApp foi conectado com sucesso!*\n\n" \
        "Agora o EscreveZap está ativo no seu celular. Sempre que você receber ou enviar um áudio, " \
        "basta reagir a ele com qualquer emoji (como 👀, 👍 ou ❤️) que eu enviarei a transcrição completa na própria conversa!"
      )

      # Manda o menu principal caso o usuário não tenha nenhuma transcrição ainda
      if transcriptions.count.zero?
        meta_service.send_list_message(
          body_text: "Como posso ajudar você hoje?",
          button_text: "Escolher opção",
          sections: [
            {
              title: "WhatsApp",
              rows: [
                { id: "menu_status", title: "📡 Status da Conexão", description: "Verificar se seu celular está ativo" },
                { id: "menu_connect", title: "🔌 Conectar / Alterar", description: "Gerar novo código de pareamento" }
              ]
            },
            {
              title: "Conta",
              rows: [
                { id: "menu_billing", title: "💳 Plano e Faturamento", description: "Ver limite, uso mensal e upgrades" },
                { id: "menu_help", title: "❓ Ajuda / Como usar", description: "Relembrar instruções de transcrição" }
              ]
            }
          ],
          header_text: "Menu Principal - EscreveZap",
          footer_text: "EscreveZap"
        )
      end
    end

    return if user.onboarding_completed?

    user.complete_onboarding!
  end

  def record_status_event
    old_status, new_status = saved_change_to_waha_status
    WahaSessionEvent.create!(
      waha_session: self,
      from_status:  old_status,
      to_status:    new_status,
      occurred_at:  Time.current
    )
  end
end
