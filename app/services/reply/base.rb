module Reply
  class Base
    include Reply::Router
    include Reply::Onboarding
    include Reply::Connectivity
    include Reply::Billing
    include Reply::FreeText
    include Reply::LongAudio

    def initialize(from:, display_name: nil, message: nil)
      @display_name = display_name
      @from = from # e.g. "5585999999999@c.us"
      @phone = from.split("@").first

      # Check if the user already exists in the database. The message only
      # matters on first contact: it carries the site's acquisition code.
      @session = WahaSession.find_or_create_for_phone!(phone: @phone, display_name: display_name, first_message: message.to_s)
      @user    = @session.user

      @current_conversation_state = @user.conversation_state || {}
      @last_reply = @current_conversation_state.dig("last_reply_at")&.to_datetime

      # Conversa parada há mais de 2h recomeça do estágio inicial, mas sem
      # esquecer que o usuário já recebeu as boas-vindas ou está silenciado.
      if @last_reply && @last_reply < 2.hours.ago
        @current_conversation_state = @current_conversation_state.slice("welcomed_at", "silenced_until").merge("stage" => "initial")
      end
    end

    def track_incoming_message(message:, interactive_reply: nil, message_id: nil, sent_at: nil, metadata: {})
      body = message.presence || interactive_reply_text(interactive_reply) || "(mensagem sem texto)"

      WhatsappMessage.create!(
        user: @user,
        phone: @phone,
        from: @from,
        to: @session.waha_chat_id.presence || "system",
        message_id: message_id,
        direction: :incoming,
        message_type: interactive_reply.present? ? :interactive : :text,
        body: body,
        metadata: {
          interactive_reply: interactive_reply.presence,
          source: "reply"
        }.merge(metadata || {}).compact,
        sent_at: sent_at.presence || Time.current
      )
    rescue => e
      Rails.logger.error "[Reply::Base#track_incoming_message] Error: #{e.class} #{e.message}"
      Sentry.capture_exception(e)
    end

    private

    def interactive_reply_text(interactive_reply)
      return nil if interactive_reply.blank?

      interactive_reply[:title].presence || interactive_reply[:id].presence
    end

    # ── Meta Service Helpers ────────────────────────────────────────────────

    def send_message(message:)
      Meta::Service.new(recipient: @phone).send_message(message)
    end

    def send_list_message(body_text:, button_text:, sections:, header_text: nil, footer_text: nil)
      Meta::Service.new(recipient: @phone).send_list_message(
        body_text: body_text,
        button_text: button_text,
        sections: sections,
        header_text: header_text,
        footer_text: footer_text
      )
    end

    def send_contact(name:, phone:)
      Meta::Service.new(recipient: @phone).send_contact(name: name, phone: phone)
    end

    def send_cta_url_message(body_text:, button_text:, url:, header_text: nil, footer_text: nil)
      Meta::Service.new(recipient: @phone).send_cta_url_message(
        body_text: body_text,
        button_text: button_text,
        url: url,
        header_text: header_text,
        footer_text: footer_text
      )
    end

    def send_pix_code(reference_id:, pix_code:, total_amount_cents:, description:)
      Meta::Service.new(recipient: @phone).send_pix_code(
        reference_id: reference_id,
        pix_code: pix_code,
        total_amount_cents: total_amount_cents,
        description: description
      )
    end
  end
end
