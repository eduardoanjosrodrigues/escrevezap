class UsageEvent < ApplicationRecord
  belongs_to :user

  TRANSCRIPTION_COMPLETED = "transcription_completed"
  AI_FORMAT_COMPLETED     = "ai_format_completed"
  TRANSCRIPTION_RATE_LIMITED         = "transcription_rate_limited"
  AUDIO_TOO_LONG                     = "audio_too_long"
  LONG_AUDIO_CONFIRMATION_REQUESTED  = "long_audio_confirmation_requested"
  LONG_AUDIO_CONFIRMED               = "long_audio_confirmed"
  LONG_AUDIO_CANCELLED               = "long_audio_cancelled"
  FIRST_CONTACT                      = "first_contact"
  FOLLOW_UP_SENT                     = "follow_up_sent"

  # Funil de pagamento: bateu no limite → tocou em assinar → recebeu o Pix →
  # pagou. LIMIT_REACHED vai a cada áudio recusado; metadata.notified diz se
  # aquele recebeu o aviso (os outros foram deduplicados).
  LIMIT_REACHED          = "limit_reached"
  CHECKOUT_STARTED       = "checkout_started"
  PIX_GENERATED          = "pix_generated"
  PIX_FAILED             = "pix_failed"
  SUBSCRIPTION_ACTIVATED = "subscription_activated"

  scope :this_month, -> { where(occurred_at: Time.current.beginning_of_month..) }
  scope :last_30_days, -> { where(occurred_at: 30.days.ago..) }

  def self.track(user:, event_type:, metadata: {})
    create!(user: user, event_type: event_type, metadata: metadata, occurred_at: Time.current)
  end
end
