require "zlib"

# Escolhe o motor de STT de cada usuário e monta o transcritor.
#
# Teste A/B: SONIOX_ROLLOUT_PERCENT (env, 0–100) define a fatia de usuários
# que vai para a Soniox. O sorteio é fixo por usuário (hash do id), então a
# mesma pessoa cai sempre no mesmo motor. users.transcription_engine fixa o
# motor à mão e passa por cima do sorteio.
module TranscriptionEngine
  ENGINES = %w[deepgram soniox gpt-4o-transcribe].freeze

  DEFAULT = (Rails.application.credentials[:transcription_engine] || "deepgram").freeze

  def self.for(user)
    return user.transcription_engine if ENGINES.include?(user.transcription_engine)
    return "soniox" if bucket(user) < rollout_percent

    DEFAULT
  end

  def self.build(engine, file_path)
    case engine
    when "soniox"            then Soniox.new(file_path)
    when "gpt-4o-transcribe" then GptTranscribe.new(file_path)
    else Deepgram.new(file_path)
    end
  end

  # 0–99, estável por usuário.
  def self.bucket(user)
    Zlib.crc32("stt-ab:#{user.id}") % 100
  end

  def self.rollout_percent
    ENV.fetch("SONIOX_ROLLOUT_PERCENT", "0").to_i.clamp(0, 100)
  end
end
