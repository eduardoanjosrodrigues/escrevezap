# Áudio recebido ou enviado numa conversa do WhatsApp conectado, com as
# chaves para baixar a mídia pelo Waxum (ver Waxum::Client#download_media).
class AudioMessage < ApplicationRecord
  belongs_to :waha_session
  has_many :transcriptions, dependent: :nullify

  # A mídia some do CDN do WhatsApp em algumas semanas; depois disso as
  # chaves não servem para nada.
  RETENTION = 30.days

  validates :message_id, :chat_jid, :phone, :direct_path, :media_key,
            :file_sha256, :file_enc_sha256, :file_length, presence: true

  scope :expired, -> { where(created_at: ...RETENTION.ago) }

  def media
    attributes.slice("direct_path", "media_key", "file_sha256", "file_enc_sha256", "file_length")
  end
end
