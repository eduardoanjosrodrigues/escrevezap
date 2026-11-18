module TranscriptionChannels
  # Delivers transcription progress/results through the user's connected
  # WhatsApp (Waxum), replying inside the original conversation.
  class WahaChannel
    def initialize(transcription)
      @transcription = transcription
      @audio         = transcription.audio_message
      @waha_session  = transcription.monitored_contact.waha_session
      # A conversa exata do áudio (pode ser @lid): a resposta citando o áudio
      # precisa ir para o mesmo chat.
      @chat_id       = @audio&.chat_jid || transcription.monitored_contact.resolve_waha_chat_id
    end

    def ready?
      @waha_session.working?
    end

    def mark_read
      return if @audio.nil? || @audio.from_me?

      @waha_session.waxum.mark_read(chat: @chat_id, message_ids: @audio.message_id)
    end

    def send_placeholder(text)
      @waha_session.waxum.send_text(to: @chat_id, text: text, reply_to: @transcription.waha_message_id)
    end

    def download_audio
      raise "Áudio sem chaves de mídia (transcription #{@transcription.id})" if @audio.nil?

      @waha_session.waxum.download_media(@audio.media)
    end

    # Long texts are split: the placeholder is edited with the first chunk and
    # the remaining chunks go out as new messages.
    def finalize(placeholder_id, text)
      first, *rest = MessageSplitter.split(text)

      if placeholder_id.present?
        @waha_session.waxum.edit_message(to: @chat_id, message_id: placeholder_id, text: first)
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
      @waha_session.waxum.send_text(to: @chat_id, text: text)
    end
  end
end
