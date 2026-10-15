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

    # Template UTILITY "whatsapp_desconectado" (pt_BR), cadastrado no WhatsApp
    # Manager. Corpo sem variáveis e um botão de resposta rápida "Reconectar",
    # cujo payload (menu_connect) cai direto no fluxo de novo código.
    def whatsapp_desconectado
      meta_json = {
        name: "whatsapp_desconectado",
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

      rendered_message = "⚠️ Seu WhatsApp foi desconectado do EscreveZap, e o Transcrever no chat (reagir ao áudio com emoji) está pausado. Encaminhar áudios para cá continua funcionando normalmente.\n\nPara reconectar, toque em *Reconectar* abaixo e gere um novo código de conexão.\n\n[Reconectar]"

      {
        meta_json: meta_json,
        rendered_message: rendered_message
      }
    end
  end
end
