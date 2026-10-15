class SeoController < ApplicationController
  # Public, never authenticated. Cache for an hour.
  skip_before_action :verify_authenticity_token, raise: false

  def robots
    expires_in 1.hour, public: true
    render plain: <<~ROBOTS
      # robots.txt — EscreveZap
      User-agent: *
      Allow: /
      Disallow: /app/
      Disallow: /admin/
      Disallow: /webhook/
      Disallow: /jobs/
      Disallow: /rails/

      Sitemap: #{SeoHelper::SITE_URL}/sitemap.xml
    ROBOTS
  end

  def sitemap
    expires_in 1.hour, public: true

    urls = []
    urls << { loc: SeoHelper::SITE_URL,                                        changefreq: "weekly",  priority: "1.0" }
    urls << { loc: "#{SeoHelper::SITE_URL}#{free_tool_path}",                  changefreq: "weekly",  priority: "0.9" }
    urls << { loc: "#{SeoHelper::SITE_URL}#{pricing_path}",                    changefreq: "monthly", priority: "0.8" }
    urls << { loc: "#{SeoHelper::SITE_URL}#{blog_index_path}",                 changefreq: "weekly",  priority: "0.8" }
    
    SeoPagesController.slugs.each do |slug|
      urls << { loc: "#{SeoHelper::SITE_URL}/#{slug}", changefreq: "weekly",  priority: "0.7" }
    end
    
    if defined?(Blog::PostsController)
      Blog::PostsController::POSTS.each do |slug, post|
        urls << { loc: "#{SeoHelper::SITE_URL}#{blog_post_path(slug)}", changefreq: "monthly", priority: "0.7", lastmod: post[:date] }
      end
    end

    urls << { loc: "#{SeoHelper::SITE_URL}#{privacidade_path}",                changefreq: "yearly",  priority: "0.2" }
    urls << { loc: "#{SeoHelper::SITE_URL}#{termos_path}",                     changefreq: "yearly",  priority: "0.2" }

    xml = +'<?xml version="1.0" encoding="UTF-8"?>'
    xml << '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
    urls.each do |u|
      lastmod = u[:lastmod] ? "<lastmod>#{u[:lastmod]}</lastmod>" : ""
      xml << "<url><loc>#{u[:loc]}</loc>#{lastmod}<changefreq>#{u[:changefreq]}</changefreq><priority>#{u[:priority]}</priority></url>"
    end
    xml << "</urlset>"

    render xml: xml
  end

  # llms.txt (https://llmstxt.org): resumo do produto para assistentes de IA,
  # gerado a partir do mesmo conteúdo do site para não ficar desatualizado.
  def llms
    expires_in 1.hour, public: true

    site  = SeoHelper::SITE_URL
    pages = SeoPagesController::PAGES.map { |slug, page| "- [#{page[:title]}](#{site}/#{slug}): #{page[:description]}" }
    posts = Blog::PostsController::POSTS.map { |slug, post| "- [#{post[:title]}](#{site}#{blog_post_path(slug)}): #{post[:description]}" }
    faqs  = HomeContent::FAQS.map { |faq| "### #{faq[:question]}\n\n#{faq[:answer]}" }

    render plain: <<~LLMS
      # EscreveZap

      > EscreveZap é um serviço brasileiro que transcreve áudios do WhatsApp em texto com IA. O usuário encaminha a mensagem de voz para o contato do EscreveZap no próprio WhatsApp e recebe a transcrição em segundos, sem instalar app, sem cadastro e sem conectar a conta. No plano Pro existe também o "Transcrever no chat": o usuário conecta o WhatsApp como aparelho conectado e reage a qualquer áudio com um emoji para a transcrição aparecer como resposta na própria conversa.

      - Site: #{site}
      - Idioma: português do Brasil (pt-BR)
      - Começar: #{site} (botão "Testar grátis no WhatsApp")

      ## Como usar

      1. No WhatsApp, segure a mensagem de voz que você quer ler (de qualquer conversa, nova ou antiga).
      2. Toque em Encaminhar e escolha o contato do EscreveZap (na primeira vez, mande um "oi" para ele).
      3. Em poucos segundos a transcrição chega na conversa com o EscreveZap. Só você vê.

      Recurso Pro "Transcrever no chat": conecte o WhatsApp ao EscreveZap (Aparelhos conectados → Conectar com número de telefone) e reaja ao áudio com qualquer emoji. A transcrição é enviada como resposta ao áudio na própria conversa, então o contato também vê. Todos os planos podem testar até 20 vezes por mês.

      ## Planos

      - Grátis: R$ 0/mês, 20 transcrições por mês.
      - Basic: R$ 5,99/mês, 500 transcrições por mês, sem a marca do EscreveZap nas respostas.
      - Pro: R$ 19,90/mês, 2.000 transcrições por mês, Transcrever no chat, formatação e resumo com IA.

      ## Páginas

      - [Página inicial](#{site}/)
      - [Preços](#{site}#{pricing_path})
      - [Testar a transcrição no navegador](#{site}#{free_tool_path})
      #{pages.join("\n")}

      ## Blog

      #{posts.join("\n")}

      ## Perguntas frequentes

      #{faqs.join("\n\n")}
    LLMS
  end
end
