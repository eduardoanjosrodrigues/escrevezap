module TranscriptionChannels
  # Delivers transcription progress/results to a user chatting directly with
  # the EscreveZap number via the Meta WhatsApp Cloud API. Unlike Waha, the
  # Cloud API has no message-edit endpoint, so there's no live-updating
  # placeholder — the final transcript is simply sent as a new message once
  # ready.
  class MetaDirectChannel
    def initialize(transcription)
      @transcription = transcription
      @phone         = transcription.monitored_contact.phone_number
    end

    def ready?
      true
    end

    # Lido + "digitando…" enquanto a transcrição é feita. Não é essencial:
    # uma falha aqui não pode impedir a transcrição.
    def mark_read
      return if @transcription.waha_message_id.blank?

      meta_service.mark_read_with_typing(@transcription.waha_message_id)
    rescue => e
      Rails.logger.warn "[MetaDirectChannel] Falha ao marcar como lida/digitando: #{e.message}"
    end

    def send_placeholder(_text)
      nil
    end

    def download_audio
      Meta::Service.download_media(@transcription.media_id, nil)
    end

    def finalize(_placeholder_id, text)
      send_text(text)
    end

    def send_text(text)
      service = meta_service
      MessageSplitter.split(text).each { |chunk| service.send_message(chunk) }
    end

    # buttons: [[id, title], ...] — title com no máximo 20 caracteres.
    def send_buttons(text, buttons)
      meta_service.send_message_with_buttons(text, buttons.map { |id, title|
        { type: "reply", reply: { id: id, title: title } }
      })
    end

    private

    def meta_service
      Meta::Service.new(recipient: @phone)
    end
  end
end
