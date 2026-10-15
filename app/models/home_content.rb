# Centralised, SEO-friendly content used by both the homepage view
# and the JSON-LD `FAQPage` schema. Keeping it in one place avoids
# drift between the rendered HTML and the structured data.
module HomeContent
  module_function

  FAQS = [
    {
      question: "Como transcrever áudio do WhatsApp em texto?",
      answer:   "Encaminhe o áudio para o EscreveZap no próprio WhatsApp e, em poucos segundos, a transcrição chega na conversa. Não precisa instalar nada nem conectar sua conta."
    },
    {
      question: "O que é o Transcrever no chat?",
      answer:   "É o recurso Pro em que você conecta seu WhatsApp ao EscreveZap como um dispositivo vinculado e reage com qualquer emoji a um áudio. A transcrição aparece como resposta na própria conversa, sem precisar encaminhar. Todos os planos podem testar até 20 vezes por mês."
    },
    {
      question: "No Transcrever no chat, a outra pessoa vê a transcrição?",
      answer:   "Sim. A transcrição é enviada como resposta ao áudio na própria conversa, então o contato também vê. Se preferir que só você veja, encaminhe o áudio para o EscreveZap."
    },
    {
      question: "Preciso trocar de número de telefone?",
      answer:   "Não. Você usa exatamente o mesmo número que já tem. Nenhuma mudança é visível para os seus contatos."
    },
    {
      question: "Posso escolher quais conversas serão transcritas?",
      answer:   "Sim. O EscreveZap só transcreve os áudios que você encaminha para ele ou, no Transcrever no chat, os que você reage com um emoji. Você decide áudio por áudio."
    },
    {
      question: "Como funciona o resumo inteligente dos áudios?",
      answer:   "No plano Pro, uma inteligência artificial lê a transcrição completa e produz um resumo curto com os pontos principais do áudio. É perfeito para mensagens de voz longas ou áudios com muita informação."
    },
    {
      question: "Meus áudios e conversas são privados?",
      answer:   "Sim. Seus áudios são usados apenas para gerar a sua transcrição e não são compartilhados com terceiros. Quando você encaminha um áudio, só você vê a transcrição."
    },
    {
      question: "Quanto custa para transcrever áudios do WhatsApp?",
      answer:   "Você pode começar de graça com 20 transcrições por mês. O plano Basic custa R$ 5,99/mês com 500 transcrições e o plano Pro custa R$ 19,90/mês com 2.000 transcrições, Transcrever no chat e resumo com IA."
    },
    {
      question: "Posso cancelar quando quiser?",
      answer:   "Sim. Sem fidelidade e sem burocracia. Você cancela a qualquer momento e continua usando até o fim do período já pago."
    }
  ].freeze

  HOW_TO_STEPS = [
    { name: "Segure o áudio",              text: "No WhatsApp, segure a mensagem de voz que você quer ler, em qualquer conversa." },
    { name: "Encaminhe para o EscreveZap", text: "Toque em Encaminhar e escolha o EscreveZap. Na primeira vez, mande um oi para salvar o contato." },
    { name: "Leia a transcrição",          text: "Em poucos segundos o texto chega na conversa com o EscreveZap. Só você vê." }
  ].freeze

  USE_CASES = [
    { emoji: "💼", title: "Em reunião",            body: "Áudio chega na hora errada. Leia o resumo em segundos sem sair da reunião." },
    { emoji: "🚗", title: "No trânsito",           body: "Não pode ouvir nem responder. Receba a transcrição e veja com calma depois." },
    { emoji: "🏢", title: "No trabalho",           body: "Sem fone, sem som, sem privacidade. Leia em vez de ouvir." },
    { emoji: "🎧", title: "Sem fone de ouvido",    body: "Não tem como ouvir sem incomodar quem está do lado." },
    { emoji: "📍", title: "Em lugar barulhento",   body: "Não consegue entender o áudio nem com volume máximo." },
    { emoji: "🤫", title: "Em silêncio",           body: "Bebê dormindo, biblioteca, hospital. A mensagem não pode esperar." },
    { emoji: "♿", title: "Acessibilidade",         body: "Quem tem perda auditiva consegue acompanhar todas as mensagens de voz." },
    { emoji: "⚡", title: "Com pressa",            body: "3 minutos de áudio. Você tem 20 segundos. Leia o resumo." }
  ].freeze

  COMPARISON_ROWS = [
    { feature: "Transcrição encaminhando o áudio",  whatsapp: false, escrevezap: true },
    { feature: "Transcrição com uma reação (Pro)",  whatsapp: false, escrevezap: true },
    { feature: "Resumo do áudio com IA",            whatsapp: false, escrevezap: true },
    { feature: "Funciona em qualquer conversa",     whatsapp: false, escrevezap: true },
    { feature: "Controle manual por áudio",         whatsapp: false, escrevezap: true },
    { feature: "Usar o seu próprio número",         whatsapp: true,  escrevezap: true },
    { feature: "Mensagens de voz nativas",          whatsapp: true,  escrevezap: true }
  ].freeze
end
