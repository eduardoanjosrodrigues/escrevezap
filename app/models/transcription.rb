class Transcription < ApplicationRecord
  belongs_to :monitored_contact
  has_one    :waha_session, through: :monitored_contact
  has_one    :user,         through: :waha_session
  has_one_attached :audio
  has_many   :provider_usages,    -> { order(created_at: :desc) }
  has_many   :transcription_errors, -> { order(created_at: :desc) }

  enum :status, {
    processing:            "processing",
    completed:             "completed",
    failed:                "failed",
    # Áudio acima do limite de duração do plano esperando o usuário aceitar
    # gastar créditos extras (ver LONG_AUDIO_CREDIT_SECONDS).
    awaiting_confirmation: "awaiting_confirmation"
  }, default: :processing

  enum :direction, {
    incoming: "incoming",
    outgoing: "outgoing"
  }, default: :incoming

  # Which transport this transcription's audio/reply travels through.
  #   :waha   → connected WhatsApp session (Waha/Baileys)
  #   :direct → user chatting directly with the EscreveZap number (Meta Cloud API)
  enum :channel, {
    waha:   "waha",
    direct: "direct"
  }, default: :waha

  # Cada bloco de 25 min de áudio longo consome uma transcrição da cota.
  LONG_AUDIO_CREDIT_SECONDS = 25.minutes.to_i

  def self.credits_for_duration(seconds)
    [ (seconds.to_f / LONG_AUDIO_CREDIT_SECONDS).ceil, 1 ].max
  end

  scope :completed, -> { where(status: :completed) }
  scope :this_month, -> { where("transcriptions.created_at >= ?", Time.current.beginning_of_month) }
  scope :recent, -> { order("transcriptions.created_at" => :desc) }

  # True when the Pro AI-formatted content is present.
  def formatted?
    summary.present? || full_formatted.present?
  end

  def llm_output_json
    payload = {}
    payload[:summary] = summary if summary.present?
    payload[:full_formatted] = full_formatted if full_formatted.present?
    return if payload.empty?

    JSON.pretty_generate(payload)
  end

  BRANDING_FOOTER = "\n\n---\n_via EscreveZap_".freeze

  def reply_text(user_override = user)
    body = full_formatted.presence || transcript
    return if body.blank?

    text = if user_override&.pro? && summary.present? && summary.length < body.length &&
              (user_override.polished? || user_override.whatsapp?)
      body_line = user_override.polished? ? "_#{body}_" : body
      [
        "📝 *Resumo rápido*\n\n#{summary}",
        "───────────────",
        "📄 *Transcrição completa*\n\n#{body_line}"
      ].join("\n\n")
    else
      "📄 *Transcrição*\n\n#{body}"
    end

    text + BRANDING_FOOTER
  end
end
