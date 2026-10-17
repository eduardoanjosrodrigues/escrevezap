module Reply
  module Router
    def reply(message:, interactive_reply: nil, message_id: nil, sent_at: nil, metadata: {})
      track_incoming_message(
        message: message,
        interactive_reply: interactive_reply,
        message_id: message_id,
        sent_at: sent_at,
        metadata: metadata
      )

      # 1. Action Router (Priority): Route by interactive action ID if present
      if interactive_reply.present? && interactive_reply[:id].present?
        route_action(interactive_reply[:id], interactive_reply)
      else
        # 2. State Router: Route based on current conversation stage
        stage = @current_conversation_state["stage"] || "initial"
        route_stage(stage, message)
      end

      @current_conversation_state["last_reply_at"] = Time.now
      @user.update!(conversation_state: @current_conversation_state)
    rescue => e
      Rails.logger.error "[Reply::Base#reply] Error in reply service: #{e.class} #{e.message}"
      Sentry.capture_exception(e)
      if Rails.env.production?
        send_message(message: "Desculpe, ocorreu um erro ao processar sua mensagem. Por favor, tente novamente em instantes. 🥺")
      else
        raise e
      end
    end

    private

    def route_action(action_id, reply_data)
      case action_id
      # Onboarding actions
      when "onboarding_connect"
        show_connection_instructions
      when "onboarding_how"
        show_how_it_works
      when "onboarding_plans"
        show_plans

      # Menu / Connection status actions
      when "menu_status"
        show_connection_status
      when "menu_connect"
        show_connection_instructions
      when "menu_billing"
        show_billing
      when "menu_help"
        show_how_it_works
      when "menu_support"
        show_support

      # Connection tracking actions
      when "pairing_ready"
        start_connection_flow
      when "verify_connection"
        verify_session_connection
      when "cancel_connection"
        cancel_connection_flow
      when "menu_disconnect_prompt"
        prompt_disconnect
      when "confirm_disconnect"
        process_disconnect

      # Billing / Upgrade actions
      # "upgrade_basic:winback" — o sufixo diz qual aviso levou ao clique
      # (vai para o CHECKOUT_STARTED, ver BotNudgeJob)
      when /\Aupgrade_(basic|pro)(?::([a-z_]+))?\z/
        generate_upgrade_checkout(Regexp.last_match(1), source: Regexp.last_match(2))
      when "upgrade_dismiss"
        send_message(message: "Tudo bem! 👍 Se mudar de ideia, é só me chamar por aqui.")
      when "cancel_subscription"
        process_subscription_cancellation

      # Áudio acima do limite de duração (id carrega a transcription)
      when /\Along_audio_confirm:(\d+)\z/
        confirm_long_audio(Regexp.last_match(1).to_i)
      when /\Along_audio_cancel:(\d+)\z/
        cancel_long_audio(Regexp.last_match(1).to_i)

      # Default fallback
      else
        show_menu
      end
    end

    def route_stage(stage, message)
      case stage
      when "waiting_for_connection"
        # Checa se o usuário já conectou. Se sim, redireciona para o menu principal
        if @session.working?
          show_menu
          return
        end

        send_list_message(
          body_text: "Ainda estou aguardando a conexão do seu WhatsApp no celular. Se você já inseriu o código, toque em 'Verificar Conexão' abaixo:",
          button_text: "Opções",
          sections: [
            {
              title: "Conexão",
              rows: [
                { id: "verify_connection", title: "📡 Verificar Conexão", description: "Verificar se a conexão foi estabelecida" },
                { id: "menu_connect", title: "🔄 Pedir Novo Código", description: "Gerar um novo código de pareamento" },
                { id: "cancel_connection", title: "❌ Cancelar e Voltar", description: "Voltar para o menu principal" }
              ]
            }
          ]
        )
      when "waiting_for_billing_cpf"
        process_billing_cpf(message)
      when "waiting_for_billing_name"
        process_billing_name(message)
      else
        handle_free_text(message)
      end
    end
  end
end
