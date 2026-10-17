class ProviderUsage < ApplicationRecord
  belongs_to :transcription

  DEEPGRAM_USD_PER_SECOND        = 0.0059 / 60.0   # Nova-3: $0.0059/min
  SONIOX_USD_PER_SECOND          = 0.10 / 3600.0   # stt-async: $0.10/hora
  OPENAI_USD_PER_TOKEN           = 5.0 / 1_000_000  # GPT-4o input: $5/1M tokens (approx average)
  GPT_TRANSCRIBE_USD_PER_TOKEN   = 6.0 / 1_000_000  # gpt-4o-transcribe: $6/1M tokens
  GPT_TRANSCRIBE_USD_PER_SECOND  = 0.006 / 60.0     # gpt-4o-transcribe: $0.006/min (duration fallback)

  scope :deepgram, -> { where(provider: "deepgram") }
  scope :soniox,   -> { where(provider: "soniox") }
  scope :openai,   -> { where(provider: "openai") }
  scope :this_month, -> { where(created_at: Time.current.beginning_of_month..) }

  def self.total_cost_usd
    sum(:cost_usd)
  end
end
