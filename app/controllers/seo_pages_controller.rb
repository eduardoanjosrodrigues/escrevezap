class SeoPagesController < ApplicationController
  layout "landing"

  # Each entry powers a full SEO landing page that converts to the same
  # CTA as the homepage. To add a new keyword landing, add an entry here
  # and a route in `config/routes.rb`. The shared template handles render.
  PAGES = {
    "converter-audio-em-texto" => {
      ref:         "seo-converter", # código de origem nos botões de WhatsApp
      keyword:     "converter áudio em texto",
      title:       "Converter Áudio em Texto pelo WhatsApp | EscreveZap",
      description: "Converta áudio em texto com IA sem sair do WhatsApp: encaminhe a mensagem de voz para o EscreveZap e receba o texto pontuado em segundos. Comece grátis.",
      h1:          "Converter áudio em texto com IA",
      intro:       "Não precisa baixar app de transcrição nem fazer upload em site. Você encaminha o áudio para o EscreveZap no próprio WhatsApp e recebe o texto pronto, com pontuação, em poucos segundos.",
      benefits: [
        { icon: "ph-microphone",        title: "Voz em texto na hora",   body: "Cada mensagem de voz encaminhada vira texto em segundos." },
        { icon: "ph-sparkle",           title: "Formatação inteligente", body: "Pontuação e parágrafos sempre. No Pro, a IA formata e gera resumo." },
        { icon: "ph-lock",              title: "Privacidade",            body: "Seus áudios são usados só para gerar a sua transcrição." },
        { icon: "ph-arrows-clockwise",  title: "Funciona 24/7",          body: "Encaminhe a qualquer hora, do celular ou do WhatsApp Web." }
      ],
      steps: [
        "Segure o dedo sobre o áudio no WhatsApp.",
        "Toque em Encaminhar.",
        "Escolha o EscreveZap e envie.",
        "Receba o áudio convertido em texto na conversa com o EscreveZap."
      ],
      faqs: [
        {
          question: "Como converter um áudio em texto sem digitar manualmente?",
          answer:   "Encaminhe o áudio para o EscreveZap no WhatsApp. A transcrição chega em poucos segundos, pronta para ler, copiar ou encaminhar."
        },
        {
          question: "Funciona com áudios longos?",
          answer:   "Sim. O EscreveZap transcreve áudios longos e, no plano Pro, a IA ainda gera um resumo curto para você ler primeiro."
        },
        {
          question: "Preciso criar conta?",
          answer:   "Não. Na primeira vez, mande um \"oi\" para o EscreveZap e já pode encaminhar seus áudios. O plano grátis inclui 5 áudios para testar."
        }
      ]
    },

    "responder-audio-whatsapp" => {
      ref:         "seo-responder", # código de origem nos botões de WhatsApp
      keyword:     "responder áudio do WhatsApp",
      title:       "Responder Áudio do WhatsApp Sem Ouvir | EscreveZap",
      description: "Responda áudio do WhatsApp sem precisar ouvir: encaminhe a mensagem de voz para o EscreveZap, leia o texto em segundos e responda de qualquer lugar.",
      h1:          "Responder áudio do WhatsApp sem precisar ouvir",
      intro:       "Em reunião, no trabalho, no transporte público ou em qualquer lugar onde não dá para tocar o áudio: encaminhe para o EscreveZap, leia a mensagem em texto e responda na hora, sem perder o contexto.",
      benefits: [
        { icon: "ph-chat-text",                title: "Leia em vez de ouvir",   body: "O áudio vira texto em poucos segundos, direto no WhatsApp." },
        { icon: "ph-headphones",               title: "Sem fone, sem problema", body: "Não precisa de fone, silêncio ou privacidade." },
        { icon: "ph-clock-counter-clockwise",  title: "Sem voltar 5 vezes",     body: "Áudios longos viram texto fácil de escanear. No Pro, com resumo." },
        { icon: "ph-smiley",                   title: "Transcrever no chat",    body: "No Pro, reaja ao áudio com um emoji e a transcrição vai como resposta." }
      ],
      steps: [
        "Segure o dedo sobre o áudio que você recebeu.",
        "Toque em Encaminhar.",
        "Escolha o EscreveZap e envie.",
        "Leia o texto, volte para a conversa e responda."
      ],
      faqs: [
        {
          question: "Como responder áudio do WhatsApp sem dar play?",
          answer:   "Encaminhe o áudio para o EscreveZap. Em poucos segundos você recebe o texto, lê e responde por texto ou áudio, sem nunca precisar tocar a mensagem original."
        },
        {
          question: "A pessoa que mandou o áudio sabe que estou usando o EscreveZap?",
          answer:   "Se você encaminha o áudio, não: a transcrição chega só na sua conversa com o EscreveZap e só você vê. Se usar o Transcrever no chat (plano Pro), a transcrição é enviada como resposta ao áudio na própria conversa, então o contato também vê."
        }
      ]
    },

    "audio-whatsapp-texto" => {
      ref:         "seo-audio-texto", # código de origem nos botões de WhatsApp
      keyword:     "áudio do WhatsApp em texto",
      title:       "Áudio do WhatsApp em Texto com IA | EscreveZap",
      description: "Transforme áudio do WhatsApp em texto: encaminhe para o EscreveZap e receba a transcrição com IA em segundos, em português do Brasil. Sem instalar nada.",
      h1:          "Áudio do WhatsApp em texto, sem complicação",
      intro:       "Pare de perder tempo ouvindo áudios longos. Encaminhe a mensagem de voz para o EscreveZap e receba o texto com pontuação, pronto para ler, em poucos segundos.",
      benefits: [
        { icon: "ph-translate",            title: "Português brasileiro nativo", body: "Modelo otimizado para o jeito que a gente fala no Brasil." },
        { icon: "ph-article",              title: "Resumo + transcrição",        body: "No Pro, você recebe o ponto principal antes do texto completo." },
        { icon: "ph-link",                 title: "Sem mudar nada no WhatsApp",  body: "Continua usando o app como sempre. É só encaminhar." },
        { icon: "ph-check-circle",         title: "Pronto em segundos",          body: "Sem cadastro e sem QR code. Mande um \"oi\" e comece." }
      ],
      steps: [
        "Segure o dedo sobre o áudio no WhatsApp.",
        "Toque em Encaminhar.",
        "Escolha o EscreveZap e envie.",
        "Leia o áudio do WhatsApp em texto na conversa com o EscreveZap."
      ],
      faqs: [
        {
          question: "Dá pra transformar áudio do WhatsApp em texto de graça?",
          answer:   "Sim. O plano grátis do EscreveZap tem 5 áudios para você testar, sem cadastro e sem cartão."
        },
        {
          question: "Posso transcrever áudios de grupos?",
          answer:   "Sim. Qualquer áudio que você consegue encaminhar, inclusive de grupos, pode ser enviado para o EscreveZap e transcrito."
        }
      ]
    },

    "como-transcrever-audio-de-cliente" => {
      ref:         "seo-cliente", # código de origem nos botões de WhatsApp
      keyword:     "transcrever áudio de cliente no WhatsApp",
      title:       "Como Transcrever Áudio de Cliente no WhatsApp",
      description: "Transcreva os áudios longos dos seus clientes no WhatsApp: encaminhe para o EscreveZap, leia o pedido em segundos e responda mais rápido. Comece grátis.",
      h1:          "Transcrever áudio de cliente no WhatsApp",
      intro:       "Atender clientes pelo WhatsApp é ótimo, até chegar aquele áudio de 4 minutos. Encaminhe o áudio para o EscreveZap e leia o pedido em texto em poucos segundos. Entenda o contexto e responda com agilidade.",
      benefits: [
        { icon: "ph-clock-user",    title: "Responda mais rápido",   body: "Leia em segundos o que levaria minutos para ouvir." },
        { icon: "ph-file-text",     title: "Pedido por escrito",     body: "Tenha o que o cliente pediu em texto, fácil de copiar." },
        { icon: "ph-briefcase",     title: "Profissionalismo",       body: "Atenda o cliente mesmo em reuniões ou locais barulhentos." },
        { icon: "ph-check-circle",  title: "Sem instalar nada",      body: "Funciona no WhatsApp comum e no WhatsApp Business." }
      ],
      steps: [
        "Segure o dedo sobre o áudio do cliente.",
        "Toque em Encaminhar.",
        "Escolha o EscreveZap e envie.",
        "Leia o pedido em texto e responda o cliente."
      ],
      faqs: [
        {
          question: "Meus clientes vão saber que estou transcrevendo?",
          answer:   "Não, se você encaminhar: a transcrição chega só na sua conversa com o EscreveZap e só você vê. Se usar o Transcrever no chat (plano Pro), a transcrição vai como resposta ao áudio e o cliente também vê, o que pode ser útil para confirmar o pedido por escrito."
        },
        {
          question: "Funciona no WhatsApp Business?",
          answer:   "Sim. Você encaminha o áudio para o EscreveZap do mesmo jeito, tanto no WhatsApp comum quanto no WhatsApp Business."
        }
      ]
    },

    "como-transcrever-audio-de-reuniao" => {
      ref:         "seo-reuniao", # código de origem nos botões de WhatsApp
      keyword:     "transcrever áudio de reunião",
      title:       "Como Transcrever Áudio de Reunião no WhatsApp",
      description: "Transcreva áudio de reunião recebido no WhatsApp: encaminhe para o EscreveZap e receba o texto em segundos. No Pro, a IA ainda gera um resumo dos pontos.",
      h1:          "Transcrever áudio de reunião no WhatsApp",
      intro:       "Alguém mandou o áudio daquela reunião importante? Não perca tempo transcrevendo manualmente. Encaminhe para o EscreveZap e receba o texto. No plano Pro, a IA ainda resume os pontos principais para você.",
      benefits: [
        { icon: "ph-list-bullets",  title: "Geração de atas",          body: "Transforme áudios longos em texto para suas atas e relatórios." },
        { icon: "ph-sparkle",       title: "Resumo automático (Pro)",  body: "A IA destaca os pontos mais importantes da reunião." },
        { icon: "ph-users",         title: "Foco no trabalho",         body: "Poupe horas de digitação e revisão." },
        { icon: "ph-lock-key",      title: "Confidencialidade",        body: "Seus áudios são usados só para gerar a sua transcrição e não são compartilhados." }
      ],
      steps: [
        "Segure o dedo sobre o áudio da reunião no WhatsApp.",
        "Toque em Encaminhar.",
        "Escolha o EscreveZap e envie.",
        "Leia o texto completo (e o resumo, no Pro) na conversa com o EscreveZap."
      ],
      faqs: [
        {
          question: "A IA consegue resumir uma reunião inteira?",
          answer:   "Sim. No plano Pro, a IA lê toda a transcrição e gera um resumo com os principais pontos discutidos."
        },
        {
          question: "E se a gravação da reunião for antiga?",
          answer:   "Sem problema. Qualquer áudio que ainda está no seu WhatsApp pode ser encaminhado para o EscreveZap e transcrito."
        }
      ]
    },

    "como-transcrever-audio-de-corretor" => {
      ref:         "seo-corretor", # código de origem nos botões de WhatsApp
      keyword:     "transcrever áudio de corretor",
      title:       "Transcrever Áudio de Corretor de Imóveis | EscreveZap",
      description: "Corretor recebe áudio o dia todo. Encaminhe para o EscreveZap e leia valores, propostas e detalhes de imóveis em texto no WhatsApp, em poucos segundos.",
      h1:          "Transcrever áudio de corretor e de negociação imobiliária",
      intro:       "Para o corretor de imóveis, informação é tudo. Encaminhe áudios de clientes e proprietários para o EscreveZap e tenha tudo em texto. Nunca mais esqueça o valor de uma proposta ou os detalhes de uma visita.",
      benefits: [
        { icon: "ph-house-line",        title: "Detalhes do imóvel",   body: "Leia metragens, valores e condições direto na tela." },
        { icon: "ph-handshake",         title: "Negociação ágil",      body: "Responda clientes mais rápido lendo em vez de ouvindo." },
        { icon: "ph-magnifying-glass",  title: "Busca facilitada",     body: "As transcrições ficam no seu WhatsApp e aparecem na busca." },
        { icon: "ph-car",               title: "Entre uma visita e outra", body: "Leia rapidamente o que o cliente disse, sem dar play." }
      ],
      steps: [
        "Segure o dedo sobre o áudio do cliente ou proprietário.",
        "Toque em Encaminhar.",
        "Escolha o EscreveZap e envie.",
        "Leia a transcrição detalhada em poucos segundos."
      ],
      faqs: [
        {
          question: "Posso pesquisar a transcrição no WhatsApp depois?",
          answer:   "Sim. A transcrição chega como mensagem de texto na sua conversa com o EscreveZap (ou, no Transcrever no chat do plano Pro, na própria conversa com o cliente), então a busca do WhatsApp encontra valores e detalhes citados no áudio."
        },
        {
          question: "O cliente vê a transcrição?",
          answer:   "Se você encaminha o áudio, não: só você vê. No Transcrever no chat (plano Pro), você reage ao áudio com um emoji e a transcrição vai como resposta na conversa, então o cliente também vê."
        }
      ]
    },

    "como-transcrever-audio-de-advogado" => {
      ref:         "seo-advogado", # código de origem nos botões de WhatsApp
      keyword:     "transcrever áudio de advogado",
      title:       "Transcrever Áudio de Advogado e de Clientes | EscreveZap",
      description: "Para advogados: transcreva áudios de clientes e colegas no WhatsApp. Encaminhe para o EscreveZap e copie o relato em texto para seus documentos em segundos.",
      h1:          "Transcrever áudio de advogado e de clientes no WhatsApp",
      intro:       "Advogados lidam com informações complexas e precisam de tudo documentado. Encaminhe os áudios do WhatsApp para o EscreveZap e receba o relato em texto, pronto para organizar o atendimento e o andamento processual.",
      benefits: [
        { icon: "ph-scales",  title: "Relato por escrito",  body: "Tenha em texto o que o cliente contou por áudio." },
        { icon: "ph-shield",  title: "Privacidade",         body: "Seus áudios são usados só para gerar a sua transcrição e não são compartilhados com terceiros." },
        { icon: "ph-files",   title: "Documentação",        body: "Facilita copiar relatos para petições e peças." },
        { icon: "ph-clock",   title: "Ganhe tempo",         body: "Leia em segundos um áudio de vários minutos." }
      ],
      steps: [
        "Segure o dedo sobre o áudio do cliente.",
        "Toque em Encaminhar.",
        "Escolha o EscreveZap e envie.",
        "Copie o texto transcrito para os seus documentos."
      ],
      faqs: [
        {
          question: "O serviço é seguro para informações confidenciais?",
          answer:   "Seus áudios são usados apenas para gerar a sua transcrição e não são compartilhados com terceiros. Quando você encaminha o áudio, a transcrição chega só na sua conversa com o EscreveZap."
        },
        {
          question: "O cliente fica sabendo que transcrevi o áudio?",
          answer:   "Não, se você encaminhar: só você vê a transcrição. No Transcrever no chat (plano Pro), a transcrição vai como resposta ao áudio e o cliente também vê."
        }
      ]
    },

    "como-transcrever-audio-de-medico" => {
      ref:         "seo-medico", # código de origem nos botões de WhatsApp
      keyword:     "transcrever áudio de médico",
      title:       "Transcrever Áudio de Médico e Pacientes | EscreveZap",
      description: "Profissionais da saúde podem transcrever áudios de pacientes no WhatsApp: encaminhe para o EscreveZap e leia o relato em texto em segundos. Comece grátis.",
      h1:          "Transcrever áudio de médico e de pacientes no WhatsApp",
      intro:       "Para médicos, psicólogos e profissionais de saúde, organizar as informações dos pacientes é vital. Encaminhe o áudio para o EscreveZap e transforme o relato por voz em texto para atualizar prontuários com mais facilidade.",
      benefits: [
        { icon: "ph-heartbeat",       title: "Agilidade no atendimento", body: "Leia sintomas e relatos antes mesmo de responder." },
        { icon: "ph-clipboard-text",  title: "Facilita prontuários",     body: "Copie o relato do paciente direto para o sistema." },
        { icon: "ph-shield-plus",     title: "Privacidade",              body: "Os áudios são usados só para gerar a sua transcrição e não são compartilhados." },
        { icon: "ph-brain",           title: "Resumo com IA (Pro)",      body: "No plano Pro, tenha o ponto principal destacado." }
      ],
      steps: [
        "Segure o dedo sobre o áudio do paciente.",
        "Toque em Encaminhar.",
        "Escolha o EscreveZap e envie.",
        "Leia a transcrição e atenda de forma mais eficiente."
      ],
      faqs: [
        {
          question: "É possível transcrever termos médicos?",
          answer:   "A transcrição usa modelos de IA modernos que reconhecem boa parte dos termos técnicos. Ainda assim, vale revisar nomes de medicamentos e termos muito específicos antes de copiar para o prontuário."
        },
        {
          question: "O paciente vê a transcrição?",
          answer:   "Se você encaminha o áudio, não: só você vê. No Transcrever no chat (plano Pro), a transcrição vai como resposta ao áudio e o paciente também vê."
        }
      ]
    },

    "como-transcrever-audio-de-professor" => {
      ref:         "seo-professor", # código de origem nos botões de WhatsApp
      keyword:     "transcrever áudio de professor",
      title:       "Transcrever Áudio de Professor e Alunos | EscreveZap",
      description: "Professores e alunos podem transcrever explicações e dúvidas em áudio no WhatsApp: encaminhe para o EscreveZap e receba o texto para estudar melhor.",
      h1:          "Transcrever áudio de professor e de alunos na hora",
      intro:       "Seja um professor tirando dúvidas ou um aluno recebendo uma explicação, áudios longos são difíceis de revisar. Encaminhe para o EscreveZap e transforme a explicação por voz em texto claro e pontuado.",
      benefits: [
        { icon: "ph-student",             title: "Facilita o estudo",      body: "Tenha explicações em texto para revisar depois." },
        { icon: "ph-chalkboard-teacher",  title: "Atendimento rápido",     body: "Professores leem dúvidas de vários alunos rapidamente." },
        { icon: "ph-text-align-left",     title: "Texto pontuado",         body: "Transcrição com pontuação para melhor compreensão." },
        { icon: "ph-share-network",       title: "Fácil de compartilhar",  body: "Encaminhe o texto da explicação para outros grupos." }
      ],
      steps: [
        "Segure o dedo sobre o áudio da explicação ou da dúvida.",
        "Toque em Encaminhar.",
        "Escolha o EscreveZap e envie.",
        "Use o texto para organizar seu material de estudo ou aula."
      ],
      faqs: [
        {
          question: "Os alunos precisam ter o app?",
          answer:   "Não. Ninguém precisa instalar nada. Quem quer ler a transcrição só encaminha o áudio para o EscreveZap no WhatsApp; quem mandou o áudio não precisa fazer nada diferente."
        },
        {
          question: "Dá para transcrever áudios de grupos da turma?",
          answer:   "Sim. Qualquer áudio que você consegue encaminhar, inclusive de grupos, pode ser enviado para o EscreveZap."
        }
      ]
    },

    "escrevezap-vs-transcricao-whatsapp" => {
      ref:         "seo-vs-nativo", # código de origem nos botões de WhatsApp
      keyword:     "transcrição nativa do WhatsApp",
      title:       "EscreveZap vs Transcrição Nativa do WhatsApp",
      description: "Compare a transcrição nativa do WhatsApp com o EscreveZap: veja quando a nativa basta e quando vale encaminhar o áudio para ter IA, formatação e resumo.",
      h1:          "EscreveZap ou transcrição nativa do WhatsApp?",
      intro:       "A transcrição nativa do WhatsApp é gratuita e prática para áudios curtos, mas não está disponível para todos os idiomas e aparelhos e às vezes não aparece. O EscreveZap é uma alternativa: você encaminha o áudio e recebe o texto pontuado, com formatação e resumo por IA no plano Pro.",
      benefits: [
        { icon: "ph-brain",                title: "IA dedicada à transcrição", body: "Modelo de transcrição com foco em português do Brasil." },
        { icon: "ph-article",              title: "Resumos (Pro)",             body: "Além do texto, a IA formata e gera um resumo." },
        { icon: "ph-arrow-bend-up-right",  title: "Funciona em qualquer aparelho", body: "Basta encaminhar, no celular ou no WhatsApp Web/Desktop." },
        { icon: "ph-smiley",               title: "Transcrever no chat (Pro)", body: "Reaja ao áudio e a transcrição vai como resposta na conversa." }
      ],
      steps: [
        "Segure o dedo sobre o áudio no WhatsApp.",
        "Toque em Encaminhar.",
        "Escolha o EscreveZap e envie.",
        "Leia a transcrição e compare com a nativa."
      ],
      faqs: [
        {
          question: "Por que usar o EscreveZap se o WhatsApp já tem transcrição?",
          answer:   "Para muita gente, a nativa basta. O EscreveZap faz sentido se a transcrição nativa não aparece no seu aparelho, se você usa muito o WhatsApp Web/Desktop, ou se quer texto formatado, resumo com IA e a opção de enviar a transcrição como resposta na conversa (Pro)."
        },
        {
          question: "Posso usar os dois?",
          answer:   "Sim. Um não interfere no outro. Você pode continuar com a transcrição nativa e encaminhar para o EscreveZap só os áudios em que quer mais qualidade ou um resumo."
        }
      ]
    },

    "transcricao-whatsapp-nao-funciona" => {
      ref:         "seo-nao-funciona", # código de origem nos botões de WhatsApp
      keyword:     "transcrição do WhatsApp não funciona",
      title:       "Transcrição do WhatsApp Não Funciona? Tente o EscreveZap",
      description: "A transcrição de áudio do WhatsApp não aparece ou não funciona? Veja causas comuns e uma alternativa: encaminhe o áudio para o EscreveZap e leia o texto.",
      h1:          "Transcrição do WhatsApp não funciona?",
      intro:       "Se a transcrição do WhatsApp não aparece, está desativada ou gera um texto confuso, você não está sozinho. Vale conferir se ela está ativada nas configurações de conversa, se o app está atualizado e se o idioma é suportado. Se mesmo assim não der, o EscreveZap é uma alternativa: você encaminha o áudio e recebe o texto.",
      benefits: [
        { icon: "ph-activity",       title: "Não depende do seu aparelho", body: "A transcrição é feita pelo EscreveZap, não pelo recurso do celular." },
        { icon: "ph-magic-wand",     title: "Texto pontuado",              body: "IA focada em português do Brasil, com pontuação." },
        { icon: "ph-lightning",      title: "Em poucos segundos",          body: "Encaminhou, o texto chega na conversa com o EscreveZap." },
        { icon: "ph-device-mobile",  title: "Funciona em todo lugar",      body: "iPhone, Android e WhatsApp Web/Desktop." }
      ],
      steps: [
        "Segure o dedo sobre o áudio que não foi transcrito.",
        "Toque em Encaminhar.",
        "Escolha o EscreveZap e envie (na primeira vez, mande um \"oi\").",
        "Leia a transcrição na conversa com o EscreveZap."
      ],
      faqs: [
        {
          question: "Por que a transcrição do WhatsApp não aparece?",
          answer:   "Normalmente porque o recurso está desativado nas configurações de conversa, o app está desatualizado, o idioma do áudio não é suportado ou o recurso ainda não chegou ao seu aparelho. Verifique esses pontos primeiro."
        },
        {
          question: "Como o EscreveZap resolve isso?",
          answer:   "A transcrição é feita pelo EscreveZap, não pelo seu celular. Você encaminha o áudio para o nosso número no WhatsApp e recebe o texto em poucos segundos, em qualquer aparelho."
        }
      ]
    },

    "transcricao-whatsapp-web" => {
      ref:         "seo-web", # código de origem nos botões de WhatsApp
      keyword:     "transcrição no WhatsApp Web",
      title:       "Transcrição de Áudio no WhatsApp Web | EscreveZap",
      description: "Transcreva áudios no WhatsApp Web sem pegar o celular: encaminhe a mensagem de voz para o EscreveZap e leia o texto no computador em poucos segundos.",
      h1:          "Transcrição de áudio no WhatsApp Web",
      intro:       "Está trabalhando no computador com o WhatsApp Web aberto e chega um áudio? Dar play nem sempre é uma opção. Encaminhe o áudio para o EscreveZap ali mesmo e leia o texto na tela do computador.",
      benefits: [
        { icon: "ph-desktop",    title: "Foco no trabalho",     body: "Não tire as mãos do teclado nem pegue o celular." },
        { icon: "ph-eye-slash",  title: "Discrição",            body: "Ninguém no escritório vai ouvir o que te mandaram." },
        { icon: "ph-copy",       title: "Fácil de copiar",      body: "Copie o texto transcrito direto no computador." },
        { icon: "ph-laptop",     title: "Funciona no Desktop",  body: "WhatsApp Web e Desktop, sem extensão e sem instalar nada." }
      ],
      steps: [
        "No WhatsApp Web, passe o mouse sobre o áudio e abra o menu da mensagem.",
        "Clique em Encaminhar.",
        "Escolha o EscreveZap e envie.",
        "Leia a transcrição na conversa com o EscreveZap, na tela do computador."
      ],
      faqs: [
        {
          question: "Preciso de alguma extensão do Chrome?",
          answer:   "Não. O EscreveZap não é uma extensão de navegador. É um contato no WhatsApp: você encaminha o áudio pelo próprio WhatsApp Web ou Desktop e recebe o texto."
        },
        {
          question: "Alguém além de mim vê a transcrição?",
          answer:   "Quando você encaminha, só você vê. No Transcrever no chat (plano Pro), a transcrição vai como resposta ao áudio e o contato também vê."
        }
      ]
    }
  }.freeze

  def show
    @page = PAGES[params[:slug]]
    return render file: Rails.public_path.join("404.html"), status: :not_found, layout: false unless @page

    @slug = params[:slug]

    render :show
  end

  # Used by the dynamic sitemap to enumerate every SEO page.
  def self.slugs
    PAGES.keys
  end
end
