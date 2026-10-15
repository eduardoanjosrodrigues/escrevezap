class User < ApplicationRecord
  devise :rememberable, :trackable, :omniauthable, omniauth_providers: [ :google_oauth2 ]

  has_one :waha_session, dependent: :destroy
  has_one :subscription, dependent: :destroy
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

  TRANSCRIPTION_LIMITS = { "free" => 20, "basic" => 500, "pro" => 2_000 }.freeze

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
    TRANSCRIPTION_LIMITS.fetch(plan, 20)
  end

  def monthly_transcriptions_used
    waha_session&.monthly_transcription_count || 0
  end

  def transcription_limit_reached?
    monthly_transcriptions_used >= transcription_limit
  end

  def active_subscriber?
    subscription&.active_or_trialing? || false
  end

  # Notificação de conta (pagamento, renovação, expiração...). Quem se cadastrou
  # pelo WhatsApp recebe lá; os demais (Google/email) recebem por email.
  def notify(subject:, text:)
    if provider == "phone" && uid.present?
      Meta::Service.new(recipient: uid).send_message(text)
    elsif email.present?
      NotificationMailer.notice(self, subject, text).deliver_later
    end
  rescue => e
    Rails.logger.error "[User#notify] Falha ao notificar user #{id}: #{e.message}"
    Sentry.capture_exception(e)
  end

  def complete_onboarding!
    update!(onboarding_completed: true)
  end
end
