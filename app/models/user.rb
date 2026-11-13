class User < ApplicationRecord
  devise :rememberable, :trackable, :omniauthable, omniauth_providers: [ :google_oauth2 ]

  has_one :waha_session, dependent: :destroy
  has_one :subscription, dependent: :destroy
  has_many :audio_packs, dependent: :destroy
  has_many :whatsapp_messages, dependent: :nullify
  has_one_attached :avatar

  enum :plan,             { free: "free", basic: "basic", pro: "pro" }, default: :free
  enum :formatting_style, { faithful: "faithful", polished: "polished", whatsapp: "whatsapp" }, default: :whatsapp

  # Only if provider is email
  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }, if: -> { provider == :email }

  validates :uid, uniqueness: { scope: :provider }, allow_blank: true

  before_save do
    if provider.to_s == "phone"
      self.email = "phone-#{uid}@escrevezap.com.br"
    end
    email.downcase! if email.present?
  end

  # Grátis: 5 transcrições na vida, contando todo o histórico (é um teste,
  # não um plano para uso contínuo). Basic e Pro: por mês.
  TRANSCRIPTION_LIMITS = { "free" => 5, "basic" => 100, "pro" => 2_000 }.freeze

  # Transcrever por reação (WhatsApp conectado) é recurso Pro: o Basic pode
  # testar até este limite por mês (no Grátis vale o limite total de 5).
  REACTION_TRIAL_LIMIT = 20

  # Formatação com IA: Basic, Pro e pacote formatam sempre; o Grátis prova
  # até este limite por mês (na prática, as 5 transcrições da vida).
  AI_FORMAT_TRIAL_LIMIT = 5

  # Duração máxima de um áudio por plano. Acima disso o Free é recusado; nos
  # planos pagos o áudio encaminhado ao bot pode ser transcrito gastando
  # créditos extras (Transcription.credits_for_duration) após confirmação.
  AUDIO_DURATION_LIMITS = { "free" => 5.minutes.to_i, "basic" => 25.minutes.to_i, "pro" => 25.minutes.to_i }.freeze

  # Áudios aceitos por minuto, por usuário. Protege contra rajadas de
  # encaminhamentos (custo de STT + rate limit da Meta por destinatário).
  TRANSCRIPTIONS_PER_MINUTE = 10

  # Os botões do site abrem o bot com um código no fim da mensagem, ex.
  # "Oi! Quero testar o EscreveZap 🎙️ [home-hero~google]": o botão clicado e,
  # quando o navegador sabe, o canal. Quem chega sem código (contato
  # compartilhado, número digitado, áudio direto) fica como "direto".
  ACQUISITION_CODE = /\[([a-z0-9-]{1,40})(?:~([a-z0-9-]{1,30}))?\]/
  ACQUISITION_DIRECT = "direto"

  def self.acquisition_from(first_message)
    match = ACQUISITION_CODE.match(first_message.to_s.downcase)
    return { acquisition_ref: ACQUISITION_DIRECT, acquisition_channel: nil } unless match

    { acquisition_ref: match[1], acquisition_channel: normalize_channel(match[2]) }
  end

  # "chatgpt-com" → "chatgpt": canal vindo de utm_source com domínio, gravado
  # no navegador antes do analytics.js normalizar (o first-touch dura 30 dias).
  def self.normalize_channel(channel)
    channel&.sub(/-(com-br|com|ai)\z/, "")
  end

  # DDD → UF, para a quebra geográfica da aquisição (só o DDD, nunca o número).
  DDD_STATES = {
    "SP" => 11..19, "RJ" => [ 21, 22, 24 ], "ES" => [ 27, 28 ], "MG" => [ 31, 32, 33, 34, 35, 37, 38 ],
    "PR" => 41..46, "SC" => 47..49, "RS" => [ 51, 53, 54, 55 ], "DF" => [ 61 ], "GO" => [ 62, 64 ],
    "TO" => [ 63 ], "MT" => [ 65, 66 ], "MS" => [ 67 ], "AC" => [ 68 ], "RO" => [ 69 ],
    "BA" => [ 71, 73, 74, 75, 77 ], "SE" => [ 79 ], "PE" => [ 81, 87 ], "AL" => [ 82 ], "PB" => [ 83 ],
    "RN" => [ 84 ], "CE" => [ 85, 88 ], "PI" => [ 86, 89 ], "PA" => [ 91, 93, 94 ], "AM" => [ 92, 97 ],
    "RR" => [ 95 ], "AP" => [ 96 ], "MA" => [ 98, 99 ]
  }.flat_map { |state, ddds| ddds.map { |ddd| [ ddd.to_s, state ] } }.to_h.freeze

  # DDD de um telefone em E.164 brasileiro ("5511987654321" → "11"); nil
  # para número estrangeiro ou usuário sem telefone (login Google).
  def self.ddd_of(phone)
    digits = phone.to_s.gsub(/\D/, "")
    digits[2, 2] if digits.start_with?("55") && digits.size.between?(12, 13) && DDD_STATES.key?(digits[2, 2])
  end

  def self.from_google(auth)
    # Try to find by provider/uid first (returning user via Google)
    user = find_by(provider: auth.provider, uid: auth.uid)

    # Then try matching existing magic-link user by email
    user ||= find_by(email: auth.info.email.downcase)

    if user
      user.update!(
        provider:   auth.provider,
        uid:        auth.uid,
        avatar_url: auth.info.image,
        name:       user.name.presence || auth.info.name
      )
      user
    else
      create!(
        email:      auth.info.email.downcase,
        name:       auth.info.name,
        provider:   auth.provider,
        uid:        auth.uid,
        avatar_url: auth.info.image
      )
    end
  end

  def display_name
    name.presence || email.split("@").first
  end

  def admin?
    admin
  end

  def transcription_limit
    return current_pack.credits if on_pack?

    TRANSCRIPTION_LIMITS.fetch(plan, TRANSCRIPTION_LIMITS["free"])
  end

  # Último pacote avulso pago (ver AudioPack)
  def current_pack
    audio_packs.paid.order(paid_at: :desc).first
  end

  # Grátis que comprou pacote: a cota passa a ser a do pacote, mesmo depois
  # de esgotado (aí oferecemos outro pacote ou assinatura).
  def on_pack?
    free? && current_pack.present?
  end

  # Recursos do Pro: assinantes Pro e quem está num pacote avulso.
  def pro_features?
    pro? || on_pack?
  end

  # O limite do Grátis é na vida (não renova); os pagos renovam todo mês;
  # o pacote conta desde o pagamento.
  def lifetime_quota?
    free? && !on_pack?
  end

  # Transcrições que contam para o limite do plano: todas (Grátis), do mês
  # (assinantes) ou desde a compra do pacote.
  def transcriptions_used(excluding: nil)
    return 0 if waha_session.nil?

    if on_pack?
      waha_session.quota_transcriptions(excluding: excluding)
                  .where(transcriptions: { created_at: current_pack.paid_at.. }).sum(:credits)
    elsif lifetime_quota?
      waha_session.lifetime_transcription_count(excluding: excluding)
    else
      waha_session.monthly_transcription_count(excluding: excluding)
    end
  end

  def max_audio_duration
    return AUDIO_DURATION_LIMITS["pro"] if on_pack?

    AUDIO_DURATION_LIMITS.fetch(plan, AUDIO_DURATION_LIMITS["free"])
  end

  # credits: quanto a transcrição em questão vai consumir (1, ou mais para
  # áudios longos confirmados).
  def transcription_limit_reached?(excluding: nil, credits: 1)
    transcriptions_used(excluding: excluding) + credits > transcription_limit
  end

  # Para exibir: no Grátis o histórico pode passar do limite (quem usou 20
  # antes da mudança para 5), então mostramos no máximo o limite.
  def transcriptions_used_for_display
    [ transcriptions_used, transcription_limit ].min
  end

  def transcription_credits_remaining(excluding: nil)
    [ transcription_limit - transcriptions_used(excluding: excluding), 0 ].max
  end

  # Quem encaminha vários áudios depois de bater no limite recebe um aviso só,
  # não um por áudio. Vale tanto o aviso do TranscribeAudioJob quanto o
  # "último áudio grátis" do TranscriptionFollowUpJob.
  LIMIT_NOTICE_COOLDOWN = 12.hours

  def limit_notice_recently_sent?
    UsageEvent.where(user: self, occurred_at: LIMIT_NOTICE_COOLDOWN.ago..)
              .where("(event_type = :limit AND metadata->>'notified' = 'true') OR " \
                     "(event_type = :follow_up AND metadata->>'kind' = 'quota_last')",
                     limit: UsageEvent::LIMIT_REACHED, follow_up: UsageEvent::FOLLOW_UP_SENT)
              .exists?
  end

  # Já recebeu o aviso `kind` (FOLLOW_UP_SENT, ver BotNudgeJob)?
  def follow_up_sent?(kind, since: nil)
    events = UsageEvent.where(user: self, event_type: UsageEvent::FOLLOW_UP_SENT).where("metadata->>'kind' = ?", kind.to_s)
    events = events.where(occurred_at: since..) if since
    events.exists?
  end

  def reaction_limit_reached?(excluding: nil)
    return false if plan == "pro" || waha_session.nil?

    waha_session.monthly_transcriptions(excluding: excluding).waha.count >= REACTION_TRIAL_LIMIT
  end

  def ai_formats_used_this_month(excluding: nil)
    return 0 if waha_session.nil?

    scope = waha_session.transcriptions.this_month.where.not(full_formatted: nil)
    scope = scope.where.not(id: excluding.id) if excluding
    scope.count
  end

  def can_ai_format?(excluding: nil)
    pro_features? || basic? || ai_formats_used_this_month(excluding: excluding) < AI_FORMAT_TRIAL_LIMIT
  end

  # Resumo com IA é do Pro e do pacote (o Grátis também vê, no teste); o
  # Basic recebe só o texto formatado.
  def ai_summary?
    !basic?
  end

  def active_subscriber?
    subscription&.active_or_trialing? || false
  end

  # Notificação de conta (pagamento, renovação, expiração...). Quem se cadastrou
  # pelo WhatsApp recebe lá; os demais (Google/email) recebem por email.
  #
  # template: { meta_json:, rendered_message: } (ver Meta::RenderTemplate). Fora
  # da janela de 24h a Meta só entrega mensagens iniciadas pela empresa via
  # template aprovado, então ele é usado no lugar do texto livre nesse caso.
  # email_cta: { label:, url: } para o botão do email.
  # Devolve true se enviou (ou enfileirou o email) e false se falhou.
  def notify(subject:, text:, template: nil, email_cta: nil)
    if provider == "phone" && uid.present?
      meta = Meta::Service.new(recipient: uid)
      if template && !whatsapp_window_open?
        meta.send_template(template[:meta_json], rendered_message: template[:rendered_message])
      else
        meta.send_message(text)
      end
    elsif email.present?
      NotificationMailer.notice(self, subject, text, email_cta).deliver_later
    else
      return false
    end
    true
  rescue => e
    Rails.logger.error "[User#notify] Falha ao notificar user #{id}: #{e.message}"
    Sentry.capture_exception(e)
    false
  end

  # A Meta permite texto livre só até 24h depois da última mensagem do usuário
  # para o bot. Margem de 1h para não errar por pouco.
  def whatsapp_window_open?
    whatsapp_messages.incoming.where(created_at: 23.hours.ago..).exists?
  end

  def complete_onboarding!
    update!(onboarding_completed: true)
  end

  class MergeError < StandardError; end

  # Assinaturas que ainda cobram (ou podem cobrar) no Inter: não dá para
  # descartar numa união de contas.
  LIVE_SUBSCRIPTION_STATUSES = %w[active trialing past_due].freeze

  # Une `other` (outra conta do mesmo número de WhatsApp) a esta e apaga
  # `other`: contatos e transcrições, eventos, mensagens, pacotes e a
  # assinatura que vale. Acontece quando alguém começa pelo bot (conta
  # "phone") e depois entra pelo site com Google e conecta o mesmo WhatsApp.
  # Se as duas contas têm assinatura viva, recusa (MergeError): é cobrança
  # dupla e precisa ser resolvida à mão.
  def absorb!(other)
    raise MergeError, "user #{id} não pode absorver a si mesmo" if other == self

    mine, theirs = subscription, other.subscription
    mine_live    = mine && LIVE_SUBSCRIPTION_STATUSES.include?(mine.status)
    theirs_live  = theirs && LIVE_SUBSCRIPTION_STATUSES.include?(theirs.status)
    raise MergeError, "users #{id} e #{other.id} têm assinatura viva" if mine_live && theirs_live

    transaction do
      if theirs && (theirs_live || mine.nil?)
        mine&.destroy!
        theirs.update!(user: self)
        self.plan = other.plan
      else
        theirs&.destroy!
      end

      absorb_waha_session!(other.waha_session) if other.waha_session

      UsageEvent.where(user_id: other.id).update_all(user_id: id)
      WhatsappMessage.where(user_id: other.id).update_all(user_id: id)
      SignInToken.where(user_id: other.id).update_all(user_id: id)
      AudioPack.where(user_id: other.id).update_all(user_id: id)

      self.acquisition_channel ||= other.acquisition_channel
      self.acquisition_ref     ||= other.acquisition_ref
      self.conversation_state    = other.conversation_state.merge(conversation_state)
      self.onboarding_completed  ||= other.onboarding_completed
      save!

      other.reload.destroy!
      reload_subscription
      UsageEvent.track(user: self, event_type: UsageEvent::ACCOUNTS_MERGED,
                       metadata: { merged_user_id: other.id, merged_provider: other.provider,
                                   subscription_id: subscription&.id })
    end

    Rails.logger.info(event: "accounts_merged", user_id: id, merged_user_id: other.id, plan: plan)
  end

  private

  # Contatos da sessão de outra conta vêm para a nossa; o mesmo número nas
  # duas vira um contato só (com as transcrições dos dois).
  def absorb_waha_session!(other_session)
    if waha_session.nil?
      other_session.update!(user: self)
      return
    end

    other_session.monitored_contacts.each do |contact|
      existing = waha_session.monitored_contacts.find_by(phone_number: contact.phone_number)
      if existing
        Transcription.where(monitored_contact_id: contact.id).update_all(monitored_contact_id: existing.id)
        contact.destroy!
      else
        contact.update!(waha_session: waha_session)
      end
    end

    other_session.reload.destroy!
  end
end
