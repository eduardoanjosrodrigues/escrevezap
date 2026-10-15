module Reply
  module Onboarding
    private

    # Quem já recebeu as boas-vindas vai direto pro menu: o fluxo principal
    # (encaminhar áudio) não depende de conectar o WhatsApp.
    def show_menu
      if @user.onboarding_completed? || @current_conversation_state["welcomed_at"].present?
        send_main_menu
      else
        start_onboarding
      end
    end

    def start_onboarding
      first_message = "Oi *#{@display_name || 'Usuário'}*, seja bem-vindo ao EscreveZap! 👋"
      second_message = "É só *encaminhar um áudio para mim* que eu te devolvo a transcrição aqui em poucos segundos. Pode testar agora! 🎙️"

      send_message(message: first_message)
      sleep 0.5.seconds
      send_message(message: second_message)
      sleep 0.5.seconds

      send_list_message(
        body_text: "Quer mais? No recurso *Transcrever no chat*, você reage a um áudio com qualquer emoji e a transcrição aparece na própria conversa.",
        button_text: "Ver opções",
        sections: [
          {
            title: "Introdução",
            rows: [
              { id: "onboarding_how", title: "❓ Como funciona?", description: "Ver instruções de uso" },
              { id: "onboarding_connect", title: "⚡ Transcrever no chat", description: "Recurso Pro · teste grátis até 20 por mês" },
              { id: "onboarding_plans", title: "💵 Planos e Preços", description: "Ver limites de transcrição e planos" }
            ]
          }
        ]
      )

      @current_conversation_state["stage"] = "initial"
      @current_conversation_state["welcomed_at"] = Time.current
    end

    def send_main_menu
      whatsapp_rows = [
        { id: "menu_status", title: "📡 Status da Conexão", description: "Verificar se seu celular está ativo" }
      ]

      if @session.working?
        whatsapp_rows << { id: "menu_disconnect_prompt", title: "🔌 Desconectar", description: "Desconectar seu WhatsApp" }
      else
        whatsapp_rows << { id: "menu_connect", title: "⚡ Transcrever no chat", description: "Recurso Pro · teste grátis até 20 por mês" }
      end

      send_list_message(
        body_text: "Como posso ajudar você hoje?",
        button_text: "Escolher opção",
        sections: [
          {
            title: "WhatsApp",
            rows: whatsapp_rows
          },
          {
            title: "Conta",
            rows: [
              { id: "menu_billing", title: "💳 Plano e Faturamento", description: "Ver limite, uso mensal e upgrades" },
              { id: "menu_help", title: "❓ Ajuda / Como usar", description: "Relembrar instruções de transcrição" }
            ]
          },
          {
            title: "Suporte",
            rows: [
              { id: "menu_support", title: "🚨 Falar com Suporte", description: "Contato do time Salva-Vidas" }
            ]
          }
        ],
        header_text: "Menu Principal - EscreveZap",
        footer_text: "EscreveZap"
      )
      @current_conversation_state["stage"] = "initial"
    end

    def show_how_it_works
      how_text = <<~MSG
        ❓ *Como funciona o EscreveZap?*

        🎙️ *Encaminhe o áudio para mim:* segure o áudio em qualquer conversa, toque em *Encaminhar* e escolha o EscreveZap. Em poucos segundos eu respondo aqui com a transcrição.

        ⚡ *Transcrever no chat (recurso Pro):* conecte seu WhatsApp e reaja a qualquer áudio com um emoji (👀, 👍, ❤️). A transcrição aparece como resposta na própria conversa, e o seu contato também vê. Todos os planos podem testar até 20 por mês.

        Simples assim! Sem precisar abrir nenhum site ou painel.
      MSG

      send_cta_url_message(
        body_text: how_text,
        button_text: "Acessar Site 🌐",
        url: "https://escrevezap.com.br"
      )
      sleep 0.5.seconds
      show_menu
    end

    def show_plans
      plans_text = <<~MSG
        💵 *Nossos Planos e Limites:*

        *1. Grátis (R$ 0)*
        - 20 transcrições por mês

        *2. Basic (R$ 5,99/mês)*
        - 500 transcrições por mês

        *3. Pro (R$ 19,90/mês)*
        - 2.000 transcrições por mês
        - *Transcrever no chat* sem limite de teste
        - Formatação inteligente com IA

        _Em todos os planos você pode testar o Transcrever no chat (reagir ao áudio) até 20 vezes por mês._
      MSG

      send_message(message: plans_text)
      sleep 0.5.seconds
      show_menu
    end

    def show_support
      send_message(message: "Precisa de ajuda? Aqui está o contato do nosso time de suporte Salva-Vidas: 🧑‍🚒")
      send_contact(name: "Suporte EscreveZap", phone: "85921606104")
      sleep 0.5.seconds
      show_menu
    end
  end
end
