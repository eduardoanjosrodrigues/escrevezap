module Reply
  module Connectivity
    private

    def start_connection_flow
      send_message(message: "🔌 *Iniciando processo de conexão...* Por favor, aguarde alguns segundos enquanto preparamos o seu código.")

      # Use robust helper to generate pairing code
      pairing_code = @session.request_pairing_code(@phone)

      instructions = <<~MSG
        🔌 *Código de Pareamento Gerado!*

        Código: ```#{pairing_code}```

        ⏱️ *O código expira em cerca de 2 minutos*, então já abra o WhatsApp e insira agora.

        *Onde inserir o código:*
        1. Abra o WhatsApp e vá em *Configurações* (ou nos três pontinhos ⋮).
        2. Toque em *Aparelhos conectados* → *Conectar um aparelho*.
        3. Toque em *Conectar com número de telefone* (abaixo da câmera do QR code).
        4. Digite o código ```#{pairing_code}```.

        Se o código expirar, eu te aviso e você pode gerar outro. Assim que a conexão for concluída, eu te aviso por aqui! 🚀
      MSG

      send_message(message: instructions)

      @current_conversation_state["stage"] = "waiting_for_connection"
      # Lido pelo PairingCodeExpiredNoticeJob para avisar só quem pediu código
      # de verdade (e não nos reinícios em massa do WAHA).
      @current_conversation_state["pairing_code_requested_at"] = Time.current.iso8601

      # Send a simple follow-up action list
      send_list_message(
        body_text: "Você pode conferir o status da conexão a qualquer momento:",
        button_text: "Opções",
        sections: [
          {
            title: "Acompanhamento",
            rows: [
              { id: "verify_connection", title: "📡 Verificar Conexão", description: "Verificar se a conexão já está ativa" },
              { id: "menu_connect", title: "🔄 Pedir Novo Código", description: "Gerar um novo código de pareamento" },
              { id: "cancel_connection", title: "❌ Cancelar", description: "Voltar para o menu principal" }
            ]
          }
        ]
      )
    end

    def verify_session_connection
      if @session.reload.working?
        @user.complete_onboarding! unless @user.onboarding_completed?

        send_message(message: "🎉 *Excelente! Seu WhatsApp foi conectado com sucesso!*\n\nAgora você já pode usar o EscreveZap à vontade.")
        send_main_menu
      else
        send_message(message: "📡 *Status atual:* #{@session.waha_status.to_s.humanize}.\n\nAinda estamos aguardando a inserção do código no celular. Caso precise de ajuda, você pode tentar gerar um novo código ou voltar ao menu.")

        send_list_message(
          body_text: "O que você deseja fazer?",
          button_text: "Opções",
          sections: [
            {
              title: "Ações",
              rows: [
                { id: "verify_connection", title: "📡 Verificar Novamente", description: "Consultar status atual da conexão" },
                { id: "menu_connect", title: "🔄 Gerar Novo Código", description: "Reiniciar conexão e obter novo código" },
                { id: "cancel_connection", title: "❌ Voltar ao Menu", description: "Cancelar pareamento e voltar" }
              ]
            }
          ]
        )
      end
    end

    def cancel_connection_flow
      @current_conversation_state["stage"] = "initial"
      show_menu
    end

    def show_connection_status
      status_msg = case @session.reload.waha_status
      when "working"
        "🟢 *Conectado e Ativo!*\nSeu WhatsApp está pronto para transcrever áudios."
      when "starting"
        "🟡 *Iniciando...*\nA sessão está sendo carregada. Aguarde uns instantes."
      when "scan_qr_code"
        "🔴 *Desconectado (Aguardando Pareamento)*\nVocê precisa conectar seu WhatsApp."
      when "stopped"
        "🔴 *Parado*\nA conexão foi pausada."
      else
        "🔴 *Desconectado*\nStatus: #{@session.waha_status.to_s.humanize}"
      end

      send_message(message: "📡 *Status da Conexão:*\n\n#{status_msg}")
      sleep 0.5.seconds

      show_menu
    end

    def prompt_disconnect
      send_list_message(
        body_text: "⚠️ *Atenção:* Ao desconectar, você não poderá transcrever nenhum áudio no seu celular até conectar novamente.\n\nTem certeza de que deseja desconectar?",
        button_text: "Opções",
        sections: [
          {
            title: "Desconexão",
            rows: [
              { id: "confirm_disconnect", title: "🔴 Sim, Desconectar", description: "Desativar serviço no meu celular" },
              { id: "cancel_connection", title: "❌ Voltar ao Menu", description: "Manter conectado e voltar" }
            ]
          }
        ]
      )
    end

    def process_disconnect
      @session.disconnect!
      @user.update!(onboarding_completed: false)

      send_message(message: "🔌 *WhatsApp desconectado com sucesso.*")
      sleep 0.5.seconds
      show_menu
    end
  end
end
