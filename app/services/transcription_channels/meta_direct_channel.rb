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

    def mark_read
      # No read-receipt call needed for this flow.
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

    private

    def meta_service
      Meta::Service.new(recipient: @phone)
    end
  end
end
