module Reply
  module Onboarding
    # Quem chega por um botão de plano do site ("[precos-pro]") já vê a opção
    # de assinar junto com as boas-vindas.
    PLAN_REFS = /\A(home-planos|precos)-(basic|pro)\z/

    private

    # Quem já recebeu as boas-vindas vai direto pro menu: o fluxo principal
    # (encaminhar áudio) não depende de conectar o WhatsApp.
    def show_menu
      welcomed? ? send_main_menu : start_onboarding
    end

    # Já viu as boas-vindas — inclusive quem começou encaminhando um áudio
    # (recebeu as boas-vindas depois da primeira transcrição).
    def welcomed?
      @user.onboarding_completed? || @current_conversation_state["welcomed_at"].present? ||
        @session.transcriptions.exists?
    end

    # Uma mensagem só, que ensina o fluxo principal: encaminhar o áudio.
    def start_onboarding
      greeting = first_name ? "Oi, *#{first_name}*! 👋" : "Oi! 👋"
      quota    = PlanMessages.free_remaining_line(@user)

      send_message(message: <<~MSG.strip)
        #{greeting} Me encaminha um áudio que eu te devolvo em texto aqui mesmo, em segundos.

        *Como:* segure o áudio em qualquer conversa → *Encaminhar* → *EscreveZap*.

        #{[ quota, "Pode testar agora 🎙️" ].compact.join(" ")}
      MSG

      offer_plans_from_site if PLAN_REFS.match?(@user.acquisition_ref.to_s)

      @current_conversation_state["stage"] = "initial"
      @current_conversation_state["welcomed_at"] = Time.current
    end

    def offer_plans_from_site
      sleep 0.5.seconds
      Meta::Service.new(recipient: @phone).send_message_with_buttons(
        "Quer assinar agora? É pelo Pix Automático, direto aqui no WhatsApp.\n\n#{PlanMessages.plans_overview}",
        PlanMessages::UPGRADE_BUTTONS.map { |id, title| { type: "reply", reply: { id: id, title: title } } }
      )
    end

    def first_name
      name = @display_name.to_s.strip.split.first
      name if name.present? && name != "Novo"
    end

    def send_main_menu
      rows = [ { id: "menu_billing", title: "📊 Meu plano e uso", description: "Saldo, renovação e assinatura" } ]

      if @session.working?
        rows << { id: "menu_status", title: "📡 Status da conexão", description: "Ver se seu WhatsApp está conectado" }
        rows << { id: "menu_disconnect_prompt", title: "🔌 Desconectar", description: "Desconectar seu WhatsApp" }
      else
        rows << { id: "menu_connect", title: "⚡ Transcrever no chat", description: "Pro: reaja ao áudio e a transcrição aparece na conversa" }
      end

      rows << { id: "menu_help", title: "❓ Como usar", description: "Como encaminhar um áudio para mim" }
      rows << { id: "menu_support", title: "🧑‍🚒 Suporte", description: "Falar com o time do EscreveZap" }

      send_list_message(
        body_text: "Como posso ajudar?",
        button_text: "Ver opções",
        sections: [ { title: "EscreveZap", rows: rows } ],
        footer_text: "Para transcrever, é só me encaminhar um áudio 🎙️"
      )
      @current_conversation_state["stage"] = "initial"
    end

    def show_how_it_works
      how_text = <<~MSG
        ❓ *Como usar o EscreveZap*

        🎙️ *Encaminhe o áudio para mim:* segure o áudio em qualquer conversa, toque em *Encaminhar* e escolha o EscreveZap. Em segundos eu respondo aqui com o texto. Só você vê.

        💡 Fixe esta conversa no topo do WhatsApp pra me achar rápido.

        ⚡ *Transcrever no chat (Pro):* conecte seu WhatsApp e reaja a qualquer áudio com um emoji (👍, ❤️, 👀). A transcrição aparece como resposta na própria conversa, e o contato também vê.
      MSG

      send_cta_url_message(
        body_text: how_text,
        button_text: "Ver no site 🌐",
        url: "https://escrevezap.com.br"
      )
    end

    def show_plans
      free = User::TRANSCRIPTION_LIMITS["free"]

      send_message(message: <<~MSG.strip)
        💵 *Planos do EscreveZap*

        • *Grátis* · #{free} áudios para testar
        #{PlanMessages.plans_overview}

        _No Basic dá pra testar o Transcrever no chat até #{User::REACTION_TRIAL_LIMIT} vezes por mês._
      MSG
      sleep 0.5.seconds

      Meta::Service.new(recipient: @phone).send_message_with_buttons(
        "Quer assinar? É pelo Pix Automático, direto aqui.",
        PlanMessages::UPGRADE_BUTTONS.map { |id, title| { type: "reply", reply: { id: id, title: title } } }
      )
    end

    def show_support
      send_message(message: "Precisa de ajuda? Fala com o nosso time de suporte por aqui: 🧑‍🚒")
      send_contact(name: "Suporte EscreveZap", phone: "85921606104")
    end
  end
end
