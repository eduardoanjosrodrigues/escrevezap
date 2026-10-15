# Entrega a transcrição no chat direto com o bot (Meta Cloud API).
#
# Fica separado do TranscribeAudioJob porque a Meta limita quantas mensagens
# seguidas podemos mandar para o mesmo número (erro 131056). Quando isso
# acontece o job se reagenda com backoff e continua do pedaço onde parou —
# sem retranscrever o áudio e sem duplicar os pedaços já entregues.
class SendTranscriptionReplyJob < ApplicationJob
  queue_as :default

  # Tentativas seguidas sem entregar nenhum pedaço antes de desistir
  # (30s, 1min, 2min, 4min, 8min, 16min ≈ 30 min de espera no total).
  MAX_ATTEMPTS   = 6
  BASE_WAIT      = 30.seconds
  CHUNK_INTERVAL = 1.second

  # Uma entrega por destinatário de cada vez: entregas paralelas para o mesmo
  # número somam rajadas e estouram o limite da Meta.
  limits_concurrency to: 1, duration: 15.minutes,
                     key: ->(transcription_id, *) { Transcription.find_by(id: transcription_id)&.monitored_contact&.phone_number || transcription_id }

  def perform(transcription_id, next_chunk = 0, attempt = 0)
    transcription = Transcription.find(transcription_id)
    user          = transcription.monitored_contact.waha_session.user
    chunks        = MessageSplitter.split(transcription.reply_text(user))
    service       = Meta::Service.new(recipient: transcription.monitored_contact.phone_number)

    sent = next_chunk
    chunks.drop(next_chunk).each do |chunk|
      sleep CHUNK_INTERVAL if sent > next_chunk
      service.send_message(chunk)
      sent += 1
    end

    Rails.logger.info "[SendTranscriptionReplyJob] Transcription #{transcription.id} entregue (#{chunks.size} mensagens)"
  rescue => e
    if Meta::Service.pair_rate_limited?(e)
      retry_after_rate_limit(transcription, e, sent:, next_chunk:, attempt:, total: chunks.size)
      return
    end

    Rails.logger.error "[SendTranscriptionReplyJob] Erro ao entregar transcription #{transcription_id}: #{e.message}"
    if transcription
      record_error!(transcription, e)
      transcription.update!(status: :failed, error_message: e.message)
      notify_failure(transcription)
    end
    raise e
  end

  private

  def retry_after_rate_limit(transcription, error, sent:, next_chunk:, attempt:, total:)
    # Se algum pedaço saiu nesta rodada, a entrega está andando: zera a contagem.
    attempt = sent > next_chunk ? 0 : attempt + 1

    if attempt >= MAX_ATTEMPTS
      give_up!(transcription, error)
      return
    end

    wait = BASE_WAIT * (2**attempt)
    Rails.logger.warn "[SendTranscriptionReplyJob] Rate limit da Meta na transcription #{transcription.id} " \
                      "(pedaço #{sent + 1}/#{total}, tentativa #{attempt}) — reenviando em #{wait.inspect}"
    self.class.set(wait: wait).perform_later(transcription.id, sent, attempt)
  end

  def give_up!(transcription, error)
    Rails.logger.error "[SendTranscriptionReplyJob] Desistindo da transcription #{transcription.id} após #{MAX_ATTEMPTS} rate limits seguidos"
    record_error!(transcription, error)
    transcription.update!(status: :failed, error_message: "Rate limit da Meta: entrega abandonada após #{MAX_ATTEMPTS} tentativas")
    Sentry.capture_exception(error)
  end

  def notify_failure(transcription)
    Meta::Service.new(recipient: transcription.monitored_contact.phone_number)
                 .send_message("❌ _Não foi possível transcrever este áudio. Tente novamente._")
  rescue => e
    Rails.logger.warn "[SendTranscriptionReplyJob] Falha ao notificar erro: #{e.message}"
  end

  def record_error!(transcription, error)
    TranscriptionError.create!(
      transcription: transcription,
      stage:         "send_whatsapp",
      error_class:   error.class.name,
      message:       error.message.to_s.truncate(2000),
      backtrace:     error.backtrace&.first(10)&.join("\n")
    )
  rescue => record_err
    Rails.logger.error "[SendTranscriptionReplyJob] Failed to record TranscriptionError: #{record_err.message}"
    Sentry.capture_exception(record_err)
  end
end
