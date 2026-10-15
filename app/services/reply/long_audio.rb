module Reply
  # Respostas aos botões enviados pelo TranscribeAudioJob quando um áudio
  # encaminhado passa do limite de duração do plano e pode ser transcrito
  # gastando créditos extras.
  module LongAudio
    # Depois disso o pedido vence: o usuário pode simplesmente encaminhar de novo.
    CONFIRMATION_TTL = 24.hours

    private

    def confirm_long_audio(transcription_id)
      transcription = pending_long_audio(transcription_id)
      return if transcription.nil?

      if @user.transcription_limit_reached?(excluding: transcription, credits: transcription.credits)
        remaining = @user.transcription_credits_remaining(excluding: transcription)
        transcription.update!(status: :failed, error_message: "Créditos insuficientes na confirmação (#{transcription.credits} > #{remaining})")
        send_message(message: "⚠️ Esse áudio precisa de *#{transcription.credits} créditos*, mas você só tem #{remaining} disponíveis este mês.")
        return
      end

      # Atômico: dois toques no botão não podem transcrever (e cobrar) duas vezes.
      claimed = Transcription.where(id: transcription.id, status: :awaiting_confirmation)
                             .update_all(status: "processing", updated_at: Time.current)
      return unless claimed == 1

      TranscribeAudioJob.perform_later(transcription.id, confirmed: true)
      TrackUsageJob.perform_later(user_id: @user.id, event_type: UsageEvent::LONG_AUDIO_CONFIRMED,
                                  metadata: { transcription_id: transcription.id, credits: transcription.credits })
      send_message(message: "_⏳ Transcrevendo com o EscreveZap! Áudios longos levam um pouquinho mais..._")
    end

    def cancel_long_audio(transcription_id)
      transcription = pending_long_audio(transcription_id)
      return if transcription.nil?

      transcription.update!(status: :failed, error_message: "Áudio longo cancelado pelo usuário")
      TrackUsageJob.perform_later(user_id: @user.id, event_type: UsageEvent::LONG_AUDIO_CANCELLED,
                                  metadata: { transcription_id: transcription.id })
      send_message(message: "Beleza, não vou transcrever esse áudio. Nenhum crédito foi usado. 👍")
    end

    def pending_long_audio(transcription_id)
      transcription = @session.transcriptions.awaiting_confirmation.find_by(id: transcription_id)

      if transcription.nil?
        send_message(message: "Esse áudio já foi processado. Se quiser transcrever de novo, é só encaminhar. 🙂")
        return
      end

      if transcription.updated_at < CONFIRMATION_TTL.ago
        transcription.update!(status: :failed, error_message: "Confirmação de áudio longo expirada")
        send_message(message: "Esse pedido expirou. Se ainda quiser a transcrição, é só encaminhar o áudio de novo. 🙂")
        return
      end

      transcription
    end
  end
end
