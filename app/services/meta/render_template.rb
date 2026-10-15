module Meta
  class RenderTemplate
    def initialize(chat)
      @chat = chat
    end

    def reengajamento_numero_antigo
      meta_json = {
        name: 'reengajamento_numero_antigo',
        language: {
          code: 'pt_BR'
        },
        components: []
      }

      rendered_message = "Header: Restauração de Fotos\n\nBody: Bom dia! Sabemos que você testou nosso serviço de restauração de fotos antigo, e gostaríamos de dizer que melhoramos muito nosso serviço, principalmente com tecnologias mais avançadas para realizar a restauração!\n\nPosso te mandar de graça a foto que você tinha mandado antes pra gente já restaurada para realizar o teste novamento, o que acha?\n\nFooter: Número oficial da Memora"

      return {
        meta_json: meta_json,
        rendered_message: rendered_message
      }
    end

    def indicacao_confirmada
      meta_json = {
        name: 'indicacao_confirmada',
        language: {
          code: 'pt_BR'
        },
        components: []
      }

      rendered_message = "Header: Indicação Confirmada\n\nBody: Uma pessoa acabou de usar seu telefone como indicação, e com isso você ganhou 1 crédito grátis!\n\nVocê quer aproveitar pra me mandar alguma foto agora?"

      return {
        meta_json: meta_json,
        rendered_message: rendered_message
      }
    end

    # Template UTILITY "transcrever_no_chat_pausado" (pt_BR, id 1544226850844758),
    # cadastrado via API. Corpo sem variáveis e um botão de resposta rápida
    # "Ver opções", cujo payload (menu_connect) mostra o passo a passo de conexão.
    # A Meta rejeitou como SCAM templates anteriores no estilo "sua conexão foi
    # perdida, reconecte" (padrão de golpe), por isso o texto evita falar em
    # código/desconexão e se apresenta como o serviço que o usuário ativou.
    def transcrever_no_chat_pausado
      meta_json = {
        name: "transcrever_no_chat_pausado",
        language: {
          code: "pt_BR"
        },
        components: [
          {
            type: "button",
            sub_type: "quick_reply",
            index: "0",
            parameters: [ { type: "payload", payload: "menu_connect" } ]
          }
        ]
      }

      rendered_message = "Olá! Aqui é o EscreveZap, o serviço de transcrição de áudios que você ativou.\n\n" \
                         "O recurso *Transcrever no chat* foi pausado porque o EscreveZap não aparece mais nos aparelhos conectados do seu WhatsApp. " \
                         "Encaminhar áudios para esta conversa continua funcionando normalmente.\n\n" \
                         "Se quiser reativar o recurso, toque em *Ver opções*.\n\n[Ver opções]"

      {
        meta_json: meta_json,
        rendered_message: rendered_message
      }
    end
  end
end
