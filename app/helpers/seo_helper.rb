module SeoHelper
  # ─────────────────────────────────────────────────────────────────────
  # Brand constants — single source of truth for SEO/JSON-LD/social cards.
  # Change here = changes everywhere.
  # ─────────────────────────────────────────────────────────────────────
  SITE_NAME    = "EscreveZap".freeze
  SITE_URL     = "https://escrevezap.com.br".freeze
  SITE_TAGLINE = "Transcreva áudios do WhatsApp em texto".freeze
  DEFAULT_DESCRIPTION = "Encaminhe o áudio do WhatsApp para o EscreveZap e receba a transcrição em texto em segundos, sem instalar nada. Grátis para começar.".freeze
  DEFAULT_OG_IMAGE = "/og-image-new.png".freeze
  SOCIAL_TWITTER   = "@escrevezap".freeze

  # ─── Title ──────────────────────────────────────────────────────────
  # Usage in views:  <% content_for :title, "Página X" %>
  # Pages can also set a full title via :title_full to bypass suffix.
  def page_title
    if content_for?(:title_full)
      content_for(:title_full)
    elsif content_for?(:title)
      "#{content_for(:title)} | #{SITE_NAME}"
    else
      "#{SITE_NAME} — #{SITE_TAGLINE}"
    end
  end

  # ─── Description ────────────────────────────────────────────────────
  def page_description
    content_for?(:description) ? content_for(:description) : DEFAULT_DESCRIPTION
  end

  # ─── Canonical (strips query string + ensures absolute URL) ─────────
  def canonical_url
    override = content_for?(:canonical) ? content_for(:canonical) : nil
    return override if override.present?

    path = request.path.to_s
    path = path.chomp("/") unless path == "/"
    "#{SITE_URL}#{path}"
  end

  # ─── Robots (set :noindex via content_for) ──────────────────────────
  def meta_robots
    return content_for(:robots) if content_for?(:robots)
    return "noindex, nofollow" if no_index_route?
    "index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1"
  end

  # Authenticated / internal routes that should never be indexed.
  def no_index_route?
    path = request.path.to_s
    path.start_with?("/app", "/admin", "/jobs", "/webhook", "/rails/")
  end

  # ─── Open Graph helpers ─────────────────────────────────────────────
  def og_title
    content_for?(:og_title) ? content_for(:og_title) : page_title
  end

  def og_image_url
    image = content_for?(:og_image) ? content_for(:og_image) : DEFAULT_OG_IMAGE
    image.start_with?("http") ? image : "#{SITE_URL}#{image}"
  end

  # ─────────────────────────────────────────────────────────────────────
  # JSON-LD helpers — each returns a <script type="application/ld+json"> tag.
  # Combine multiple in a layout with simple concatenation.
  # ─────────────────────────────────────────────────────────────────────
  def jsonld_tag(data)
    content_tag(:script,
                raw(data.to_json),
                type: "application/ld+json")
  end

  def organization_jsonld
    jsonld_tag(
      "@context" => "https://schema.org",
      "@type"    => "Organization",
      "name"     => SITE_NAME,
      "url"      => SITE_URL,
      "logo"     => "#{SITE_URL}/logo.png",
      "sameAs"   => []
    )
  end

  def website_jsonld
    jsonld_tag(
      "@context" => "https://schema.org",
      "@type"    => "WebSite",
      "name"     => SITE_NAME,
      "url"      => SITE_URL,
      "inLanguage" => "pt-BR"
    )
  end

  def software_application_jsonld
    jsonld_tag(
      "@context"        => "https://schema.org",
      "@type"           => "SoftwareApplication",
      "name"            => SITE_NAME,
      "description"     => DEFAULT_DESCRIPTION,
      "url"             => SITE_URL,
      "applicationCategory"   => "CommunicationApplication",
      "applicationSubCategory" => "WhatsApp audio transcription",
      "operatingSystem" => "Web, iOS, Android",
      "inLanguage"      => "pt-BR",
      "image"           => "#{SITE_URL}#{DEFAULT_OG_IMAGE}",
      "brand"           => { "@type" => "Brand", "name" => SITE_NAME },
      "offers"          => [
        { "@type" => "Offer", "name" => "Gratuito", "price" => "0",     "priceCurrency" => "BRL" },
        { "@type" => "Offer", "name" => "Basic",    "price" => "5.99",  "priceCurrency" => "BRL" },
        { "@type" => "Offer", "name" => "Pro",      "price" => "19.90", "priceCurrency" => "BRL" }
      ]
    )
  end

  # Pass an array of {question:, answer:} hashes.
  def faq_jsonld(faqs)
    return "" if faqs.blank?

    jsonld_tag(
      "@context"   => "https://schema.org",
      "@type"      => "FAQPage",
      "mainEntity" => faqs.map { |f|
        {
          "@type" => "Question",
          "name"  => f[:question],
          "acceptedAnswer" => {
            "@type" => "Answer",
            "text"  => f[:answer]
          }
        }
      }
    )
  end

  # Pass a name and an array of {name:, text:} steps.
  def howto_jsonld(name:, steps:)
    jsonld_tag(
      "@context" => "https://schema.org",
      "@type"    => "HowTo",
      "name"     => name,
      "inLanguage" => "pt-BR",
      "totalTime"  => "PT1M",
      "step"     => steps.each_with_index.map { |step, idx|
        { "@type" => "HowToStep", "position" => idx + 1, "name" => step[:name], "text" => step[:text] }
      }
    )
  end

  # Pass an array of {name:, url:} hashes (url can be relative).
  def breadcrumb_jsonld(items)
    return "" if items.blank?

    jsonld_tag(
      "@context"        => "https://schema.org",
      "@type"           => "BreadcrumbList",
      "itemListElement" => items.each_with_index.map { |item, idx|
        {
          "@type"    => "ListItem",
          "position" => idx + 1,
          "name"     => item[:name],
          "item"     => item[:url].to_s.start_with?("http") ? item[:url] : "#{SITE_URL}#{item[:url]}"
        }
      }
    )
  end
end
