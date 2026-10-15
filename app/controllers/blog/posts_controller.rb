module Blog
  class PostsController < ApplicationController
    layout "landing"

    POSTS = {
      "como-transcrever-audio-whatsapp" => {
        title: "Como Transcrever Áudio do WhatsApp Gratuitamente",
        description: "Aprenda passo a passo como converter mensagens de voz do WhatsApp em texto usando IA.",
        author: "Equipe EscreveZap",
        date: "2026-06-24",
        content: <<~HTML
          <p class="mb-4">Se você recebe muitos áudios no WhatsApp todos os dias, sabe como isso pode atrasar sua rotina. Nem sempre estamos em um local silencioso, ou simplesmente preferimos ler a ouvir um áudio de 3 minutos.</p>
          <h2 class="text-2xl font-bold text-(--color-text) mt-8 mb-4">A solução nativa</h2>
          <p class="mb-4">O WhatsApp lançou recentemente uma funcionalidade de transcrição nativa. Ela funciona bem para áudios curtos e claros. No entanto, muitos usuários relatam instabilidades, dificuldade com sotaques e interrupções frequentes do serviço.</p>
          <h2 class="text-2xl font-bold text-(--color-text) mt-8 mb-4">A melhor alternativa: Inteligência Artificial Dedicada</h2>
          <p class="mb-4">A forma mais simples de transcrever áudios com IA é usar uma ferramenta que funciona dentro do próprio WhatsApp. Com o <strong>EscreveZap</strong>, você encaminha o áudio para o nosso número e recebe o texto formatado e pontuado em poucos segundos, sem precisar dar play, instalar app ou criar cadastro.</p>
          <h3 class="text-xl font-bold text-(--color-text) mt-6 mb-3">Como funciona:</h3>
          <ol class="list-decimal pl-6 mb-6 space-y-2">
            <li>Segure o dedo sobre o áudio e toque em <strong>Encaminhar</strong>.</li>
            <li>Escolha o EscreveZap na lista de contatos e envie (na primeira vez, mande um "oi" para o EscreveZap).</li>
            <li>A transcrição chega em segundos na sua conversa com o EscreveZap. Só você vê.</li>
          </ol>
          <p class="mb-4">A principal vantagem de usar IA dedicada é a <strong>qualidade do texto</strong>. Enquanto a transcrição comum muitas vezes ignora pontuação, a IA formata o texto com vírgulas e pontos, facilitando imensamente a leitura.</p>
          <p class="mb-4">E se você quiser que a transcrição apareça como resposta ao áudio na própria conversa, o plano Pro tem o recurso <strong>Transcrever no chat</strong>: basta reagir ao áudio com qualquer emoji. Nesse caso, o contato também vê a transcrição.</p>
        HTML
      },
      "como-ler-audios-whatsapp-sem-ouvir" => {
        title: "Como Ler Áudios do WhatsApp Sem Precisar Ouvir",
        description: "Descubra como ler suas mensagens de voz do WhatsApp em texto, ideal para reuniões ou locais públicos.",
        author: "Equipe EscreveZap",
        date: "2026-06-23",
        content: <<~HTML
          <p class="mb-4">Você está no meio de uma reunião importante e recebe um áudio do seu chefe. O que fazer? Ouvir está fora de cogitação, e ignorar pode ser um erro.</p>
          <p class="mb-4">A solução moderna para esse problema é <strong>ler o áudio</strong>.</p>
          <h2 class="text-2xl font-bold text-(--color-text) mt-8 mb-4">Como ler um áudio?</h2>
          <p class="mb-4">Ferramentas de transcrição transformam a voz em texto. O ideal é que essa ferramenta funcione dentro do próprio WhatsApp, para que você não precise baixar o arquivo, abrir outro aplicativo e fazer upload (o que quebra o fluxo da conversa).</p>
          <h2 class="text-2xl font-bold text-(--color-text) mt-8 mb-4">Encaminhe e leia</h2>
          <p class="mb-4">Com o EscreveZap, ler um áudio é instantâneo. Veja os passos:</p>
          <ul class="list-disc pl-6 mb-6 space-y-2">
            <li>Segure o dedo sobre o áudio e toque em Encaminhar.</li>
            <li>Escolha o EscreveZap e envie.</li>
            <li>Leia a transcrição que chega na sua conversa com o EscreveZap.</li>
          </ul>
          <p class="mb-4">Ler é comprovadamente mais rápido que ouvir. Um áudio de 2 minutos pode ser lido em cerca de 20 segundos. Se o áudio for muito longo, a IA do EscreveZap no plano Pro ainda gera um <strong>resumo</strong> com os principais tópicos antes do texto completo.</p>
        HTML
      },
      "como-resumir-audios-whatsapp" => {
        title: "Como Resumir Áudios Longos do WhatsApp com IA",
        description: "Chega de ouvir áudios de 5 minutos. Aprenda a usar Inteligência Artificial para resumir mensagens de voz no WhatsApp.",
        author: "Equipe EscreveZap",
        date: "2026-06-22",
        content: <<~HTML
          <p class="mb-4">"Vou te mandar um áudio rápido..." e lá se vão 5 minutos de gravação. Áudios longos muitas vezes dão voltas e perdem o foco. O que você realmente precisa é do ponto principal.</p>
          <h2 class="text-2xl font-bold text-(--color-text) mt-8 mb-4">O poder do Resumo por IA</h2>
          <p class="mb-4">Inteligências Artificiais modernas (como o GPT-4o e Claude 3.5) não apenas transcrevem áudios, elas conseguem <strong>entender o contexto</strong>. Isso permite que a IA extraia o sumo da conversa e entregue a você em tópicos (bullet points).</p>
          <h2 class="text-2xl font-bold text-(--color-text) mt-8 mb-4">Como obter resumos no WhatsApp</h2>
          <p class="mb-4">O EscreveZap possui um recurso nativo para isso em seu plano Pro. Funciona assim:</p>
          <ol class="list-decimal pl-6 mb-6 space-y-2">
            <li>Você encaminha o áudio para o EscreveZap no WhatsApp.</li>
            <li>O sistema transcreve tudo em texto.</li>
            <li>Em seguida, a IA analisa a transcrição e adiciona um bloco "Resumo" no topo da mensagem, destacando a ação necessária ou a decisão tomada.</li>
          </ol>
          <p class="mb-4">Essa funcionalidade tem salvado horas de vida de profissionais como advogados, corretores de imóveis e vendedores, que lidam com clientes prolixos diariamente.</p>
        HTML
      },
      "transcricao-whatsapp-vs-escrevezap" => {
        title: "Transcrição do WhatsApp vs EscreveZap: Qual é Melhor?",
        description: "Uma comparação detalhada entre a transcrição nativa do WhatsApp e o EscreveZap com inteligência artificial avançada.",
        author: "Equipe EscreveZap",
        date: "2026-06-21",
        content: <<~HTML
          <p class="mb-4">Com a introdução da transcrição nativa no WhatsApp, muitos se perguntam: ainda vale a pena usar uma ferramenta dedicada como o EscreveZap?</p>
          <p class="mb-4">A resposta curta é: depende da sua necessidade de uso.</p>
          <h2 class="text-2xl font-bold text-(--color-text) mt-8 mb-4">A Transcrição Nativa do WhatsApp</h2>
          <p class="mb-4">É gratuita e já vem embutida no aplicativo. É excelente para o usuário casual que precisa de vez em quando ler um áudio de 15 segundos da mãe. No entanto, ela peca na formatação (muitas vezes é um bloco gigante de texto sem pontuação) e pode falhar em sotaques mais densos ou palavras técnicas.</p>
          <h2 class="text-2xl font-bold text-(--color-text) mt-8 mb-4">A Transcrição do EscreveZap</h2>
          <p class="mb-4">Desenhada para uso profissional ou para quem lida com alto volume de áudios. Suas vantagens incluem:</p>
          <ul class="list-disc pl-6 mb-6 space-y-2">
            <li><strong>IA de Ponta:</strong> Maior precisão em português do Brasil e termos técnicos.</li>
            <li><strong>Formatação:</strong> O texto vem com pontuação correta e dividido em parágrafos.</li>
            <li><strong>Resumos (Pro):</strong> Áudios longos são resumidos antes da transcrição.</li>
            <li><strong>Flexibilidade:</strong> Funciona em qualquer aparelho, inclusive no WhatsApp Web/Desktop: basta encaminhar o áudio. No Pro, você também pode reagir ao áudio com um emoji para a transcrição ir como resposta na conversa.</li>
          </ul>
          <p class="mb-4">Se o seu WhatsApp é sua ferramenta de trabalho, uma transcrição confiável é um investimento que se paga em poucos dias com o tempo economizado.</p>
        HTML
      },
      "como-transformar-audio-em-texto" => {
        title: "Como Transformar Áudio em Texto Rapidamente",
        description: "As melhores ferramentas e métodos para transformar voz em texto, com foco na agilidade e precisão no WhatsApp.",
        author: "Equipe EscreveZap",
        date: "2026-06-20",
        content: <<~HTML
          <p class="mb-4">Transformar áudio em texto (Speech-to-Text) nunca foi tão acessível. Seja para transcrever uma aula, uma entrevista ou apenas a mensagem de um amigo no WhatsApp, existem várias opções disponíveis.</p>
          <h2 class="text-2xl font-bold text-(--color-text) mt-8 mb-4">Ferramentas de Upload</h2>
          <p class="mb-4">Existem muitos sites onde você pode enviar um arquivo MP3 ou WAV e receber o texto. Nossa <a href="/transcrever-audio" class="text-(--color-brand) hover:underline">Ferramenta Gratuita de Transcrição</a> é um ótimo exemplo. É útil para arquivos já gravados no seu computador.</p>
          <h2 class="text-2xl font-bold text-(--color-text) mt-8 mb-4">Ditado por Voz</h2>
          <p class="mb-4">Teclados modernos no iOS e Android possuem botões de microfone. Você fala e o celular digita. É excelente para criar mensagens, mas não ajuda quando você <strong>recebe</strong> um áudio e quer ler o que a outra pessoa disse.</p>
          <h2 class="text-2xl font-bold text-(--color-text) mt-8 mb-4">Transcrição Direta no WhatsApp</h2>
          <p class="mb-4">Para quem quer transformar áudio em texto sem sair do WhatsApp, a solução mais prática é um "robô" de transcrição que funciona como um contato, como o EscreveZap. Você encaminha o áudio para ele, a IA processa e o texto chega em poucos segundos na sua conversa com o EscreveZap. No plano Pro, o recurso Transcrever no chat ainda permite reagir ao áudio com um emoji para receber o texto como resposta, logo abaixo do áudio original.</p>
        HTML
      }
    }.freeze

    def index
      @posts = POSTS
    end

    def show
      @post = POSTS[params[:slug]]
      return render file: Rails.public_path.join("404.html"), status: :not_found, layout: false unless @post

      @slug = params[:slug]
    end
  end
end
