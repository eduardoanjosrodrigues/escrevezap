class WahaSession < ApplicationRecord
  belongs_to :user
  has_many :monitored_contacts, dependent: :destroy
  has_many :transcriptions, through: :monitored_contacts
  has_many :waha_session_events, dependent: :destroy
  has_many :audio_messages, dependent: :delete_all

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
  # first_message: texto da primeira mensagem ao bot (nil quando o contato
  # começa encaminhando um áudio); carrega o código de origem do site.
  def self.find_or_create_for_phone!(phone:, display_name: nil, first_message: nil)
    session = find_or_initialize_by(waha_chat_id: "#{phone}@c.us")

    if session.new_record?
      acquisition = User.acquisition_from(first_message)
      session.user = User.create!(
        name:     display_name.presence || "Novo usuário",
        provider: :phone,
        uid:      phone,
        **acquisition
      )
      session.save!

      UsageEvent.track(user: session.user, event_type: UsageEvent::FIRST_CONTACT,
                       metadata: acquisition.merge(via: first_message.nil? ? "audio" : "text").compact)
      Rails.logger.info(event: "bot_first_contact", user_id: session.user.id, **acquisition)
      ActivationNudgeJob.schedule(session.user)
    end

    session
  end

  # Um número de WhatsApp = uma conta. Quem começou pelo bot já tem uma sessão
  # com este waha_chat_id (conta "phone"); ao conectar o mesmo WhatsApp por
  # outra conta (ex.: Google no site), a conta antiga é unida a esta, que é a
  # logada no site. A sessão antiga, se chegou a rodar no Waha, é apagada lá.
  def absorb_duplicate_sessions!
    return if waha_chat_id.blank?

    WahaSession.where(waha_chat_id: waha_chat_id).where.not(id: id).find_each do |other|
      user.absorb!(other.user)

      unless other.pending?
        begin
          other.waxum.delete_session
        rescue => e
          Rails.logger.warn "[WahaSession#absorb_duplicate_sessions!] #{other.session_name}: #{e.message}"
        end
      end
    rescue User::MergeError => e
      Rails.logger.error(event: "accounts_merge_refused", user_id: user_id, other_user_id: other.user_id, error: e.message)
      Sentry.capture_exception(e)
    end
  end

  # Status no app ↔ sessão no Waxum (o nome da sessão é o mesmo).
  def waxum
    Waxum::Client.new(session: session_name)
  end

  # Garante a sessão no Waxum (criando se não existe), com o webhook do app,
  # e manda conectar. Sessão já pareada reconecta sozinha com as chaves.
  def connect!
    waxum.create_session if waxum.session_info.nil?
    waxum.ensure_webhook!
    waxum.connect
    update!(waha_status: :starting) unless working?
  rescue => e
    update!(waha_status: :failed)
    raise e
  end
  alias_method :reconnect!, :connect!

  # Para de receber eventos (o aparelho continua vinculado).
  def disconnect!
    waxum.disconnect
    update!(waha_status: :stopped)
  rescue => e
    Rails.logger.warn "[WahaSession#disconnect!] #{e.message}"
    Sentry.capture_exception(e)
    update!(waha_status: :stopped)
  end

  # Código de 8 letras para conectar pelo número ("Conectar com número de
  # telefone" no WhatsApp). Vale ~3 minutos.
  def request_pairing_code(phone_number)
    phone = phone_number.to_s.gsub(/\D/, "")
    raise "Número de telefone inválido" if phone.blank?

    waxum.create_session if waxum.session_info.nil?
    waxum.ensure_webhook!
    code = waxum.pair(phone)
    update!(waha_status: :scan_qr_code)
    WahaSessionPairingCheckJob.set(wait: WahaSessionPairingCheckJob::INTERVAL).perform_later(id)
    code
  rescue => e
    Rails.logger.error "[WahaSession#request_pairing_code] #{e.class} #{e.message}"
    raise e
  end

  # Número e nome do WhatsApp conectado (os eventos de conexão do Waxum não
  # trazem, e o session_info fica sem número quando o pareamento é por
  # código). Une contas duplicadas do mesmo número (ver absorb_duplicate_sessions!).
  def sync_profile!
    profile = waxum.profile
    phone = profile["phone_number"].to_s.gsub(/\D/, "")
    return if phone.blank?

    update!(waha_chat_id: "#{phone}@c.us", display_name: display_name.presence || profile["name"].presence)
    absorb_duplicate_sessions!
  end

  # Transcriptions that count toward the quota. Failed ones don't, and neither
  # do ones stuck in processing for over an hour (abandoned jobs). `excluding`
  # leaves out the transcription whose quota is being checked, so the last
  # audio of the plan still goes through.
  def quota_transcriptions(excluding: nil)
    scope = transcriptions.where.not(status: [ :failed, :awaiting_confirmation ])
                          .where("transcriptions.status <> 'processing' OR transcriptions.created_at > ?", 1.hour.ago)
    excluding ? scope.where.not(id: excluding.id) : scope
  end

  def monthly_transcriptions(excluding: nil)
    quota_transcriptions(excluding: excluding).merge(Transcription.this_month)
  end

  # Soma créditos, não registros: um áudio longo confirmado vale várias
  # transcrições da cota.
  def monthly_transcription_count(excluding: nil)
    monthly_transcriptions(excluding: excluding).sum(:credits)
  end

  # Plano Grátis: o limite conta o histórico inteiro.
  def lifetime_transcription_count(excluding: nil)
    quota_transcriptions(excluding: excluding).sum(:credits)
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

  # O código de pareamento expira em ~3min e a sessão vai para failed.
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

    # Only greet on an actual pairing (QR/pairing code accepted). The gateway
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
                { id: "menu_billing", title: "📊 Meu plano e uso", description: "Saldo, renovação e assinatura" },
                { id: "menu_help", title: "❓ Como usar", description: "Como encaminhar um áudio para mim" }
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
