module ExternalEvents
  module WhatsappParsers
    # Parser for META (WhatsApp Cloud API) webhook payloads
    # Transforms Meta webhook format into standardized format
    class MetaParser < Base
      def parse
        {
          event: determine_event_type,
          session: extract_session_identifier,
          payload: build_payload
        }
      end

      private

      def determine_event_type
        # Check if it's a message or status update
        value = @raw_data.dig(:entry, 0, :changes, 0, :value)

        if value&.dig(:messages).present?
          "message"
        elsif value&.dig(:statuses).present?
          "message.ack"
        elsif value&.dig(:metadata).present?
          "session.status"
        else
          "unknown"
        end
      end

      # For Meta, the "session" is the phone_number_id
      def extract_session_identifier
        @raw_data.dig(:entry, 0, :changes, 0, :value, :metadata, :phone_number_id)
      end

      def build_payload
        case determine_event_type
        when "session.status"
          build_session_status_payload
        when "message.ack"
          build_message_ack_payload
        when "message"
          build_message_payload
        else
          {}
        end
      end

      # Session status for Meta (if applicable)
      # Meta doesn't have explicit session status events like WAHA
      # But we can infer from webhook structure
      def build_session_status_payload
        {
          status: "working", # Meta webhooks being received means session is working
          waha_chat_id: extract_session_identifier
        }
      end

      # Message ACK (status) payload
      # Input: Meta status update webhook
      # Output: Standardized ACK format
      def build_message_ack_payload
        status = @raw_data.dig(:entry, 0, :changes, 0, :value, :statuses, 0)

        if status[:status]&.downcase == "failed"
          log_warning "Meta status failed received: #{status.dig(:errors, 0, :error_data, :details)}"
        end

        {
          message_id: status[:id],
          ack: normalize_meta_status(status[:status]),
          error: status.dig(:errors, 0, :error_data, :details) || nil
        }
      end

      # Message payload
      # Input: Meta message webhook
      # Output: Standardized message format
      def build_message_payload
        message = @raw_data.dig(:entry, 0, :changes, 0, :value, :messages, 0)

        base_payload = {
          display_name: @raw_data.dig(:entry, 0, :changes, 0, :value, :contacts, 0, :profile, :name) || "Unknown",
          from: message[:from] + "@c.us",
          fromMe: false, # Meta webhooks are always incoming messages
          message_id: message[:id],
          created_at: parse_timestamp(message[:timestamp]),
          body: extract_message_body(message),
          hasMedia: has_media?(message),
          reply_to_message_id: message.dig(:context, :message_id)
        }

        # Add media information based on message type
        if has_media?(message)
          base_payload[:media] = build_media_info(message)
        end

        # Botão de resposta rápida de template: o payload é o id da ação
        if message[:type] == "button"
          base_payload[:interactive_reply] = {
            type: "button",
            id: message.dig(:button, :payload),
            title: message.dig(:button, :text)
          }
        end

        # Capture interactive message reply details
        if message[:type] == "interactive"
          interactive_type = message.dig(:interactive, :type)
          if interactive_type == "button_reply"
            base_payload[:interactive_reply] = {
              type: "button",
              id: message.dig(:interactive, :button_reply, :id),
              title: message.dig(:interactive, :button_reply, :title)
            }
          elsif interactive_type == "list_reply"
            base_payload[:interactive_reply] = {
              type: "list",
              id: message.dig(:interactive, :list_reply, :id),
              title: message.dig(:interactive, :list_reply, :title)
            }
          end
        end

        base_payload
      end

      # Extract message body based on message type
      def extract_message_body(message)
        case message[:type]
        when "text"
          message.dig(:text, :body)
        when "button"
          message.dig(:button, :text)
        when "image"
          message.dig(:image, :caption) || "Image"
        when "document"
          message.dig(:document, :caption) || message.dig(:document, :filename) || "Document"
        when "audio"
          "Audio message: waiting for transcription"
        when "contacts"
          "Contact message:\n\nName: #{message.dig(:contacts, 0, :name, :formatted_name)}\nPhone: #{message.dig(:contacts, 0, :phones, 0, :phone)}"
        when 'interactive'
          interactive_type = message.dig(:interactive, :type)
          if interactive_type == "button_reply"
            "Button reply: #{message.dig(:interactive, :button_reply, :title)}"
          elsif interactive_type == "list_reply"
            "List reply: #{message.dig(:interactive, :list_reply, :title)}"
          else
            "Interactive message of type #{interactive_type}"
          end
        else
          "Unsupported message type: #{message[:type]}"
        end
      end

      # Check if message has media
      def has_media?(message)
        %w[image document audio video sticker].include?(message[:type])
      end

      # Build media information from Meta message
      def build_media_info(message)
        case message[:type]
        when "image"
          {
            url: nil, # Meta requires separate API call to get media URL
            media_id: message.dig(:image, :id),
            mimetype: message.dig(:image, :mime_type),
            filename: message.dig(:image, :caption) || "image.jpg"
          }
        when "document"
          {
            url: nil, # Meta requires separate API call to get media URL
            media_id: message.dig(:document, :id),
            mimetype: message.dig(:document, :mime_type),
            filename: message.dig(:document, :filename)
          }
        when "audio"
          {
            url: nil, # Meta requires separate API call to get media URL
            media_id: message.dig(:audio, :id),
            mimetype: message.dig(:audio, :mime_type),
            filename: "audio.ogg"
          }
        when "video"
          {
            url: nil, # Meta requires separate API call to get media URL
            media_id: message.dig(:video, :id),
            mimetype: message.dig(:video, :mime_type),
            filename: "video.mp4"
          }
        else
          {}
        end
      end

      # Normalize Meta status to match WAHA format (integer values)
      def normalize_meta_status(meta_status)
        {
          "sent" => 1,
          "delivered" => 2,
          "read" => 3,
          "failed" => -1
        }[meta_status&.downcase]
      end
    end
  end
end
