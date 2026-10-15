module TranscriptionChannels
  # Delivers transcription progress/results through a connected Waha session —
  # the original transport TranscribeAudioJob was built around.
  class WahaChannel
    def initialize(transcription)
      @transcription = transcription
      @contact       = transcription.monitored_contact
      @waha_session  = @contact.waha_session
      @chat_id       = @contact.resolve_waha_chat_id
    end

    def ready?
      @waha_session.working?
    end

    def mark_read
      @waha_session.waha_client.chats.read_messages(chat_id: @chat_id)
    end

    def send_placeholder(text)
      response = @waha_session.waha_client.messaging.send_text(
        chat_id:  @chat_id,
        text:     text,
        reply_to: @transcription.waha_message_id
      )
      response["id"]
    end

    def download_audio
      @waha_session.waha_client.messaging.download_media_from_url(media_url: @transcription.media_url)
    end

    # Long texts are split: the placeholder is edited with the first chunk and
    # the remaining chunks go out as new messages.
    def finalize(placeholder_id, text)
      first, *rest = MessageSplitter.split(text)

      if placeholder_id.present?
        @waha_session.waha_client.messaging.edit_message(
          chat_id:    @chat_id,
          message_id: placeholder_id,
          text:       first
        )
      else
        send_chunk(first)
      end

      rest.each { |chunk| send_chunk(chunk) }
    end

    def send_text(text)
      MessageSplitter.split(text).each { |chunk| send_chunk(chunk) }
    end

    private

    def send_chunk(text)
      @waha_session.waha_client.messaging.send_text(chat_id: @chat_id, text: text)
    end
  end
end
