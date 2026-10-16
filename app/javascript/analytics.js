// Analytics da landing: eventos no Umami + canal de origem nos botões do bot.
//
// Os botões de WhatsApp levam um código do botão na mensagem ("[home-hero]",
// ver official_whatsapp_url). Aqui, no clique, acrescentamos o canal da
// primeira visita com origem conhecida ("[home-hero~google]") para o bot
// registrar no User. Isso não depende do Umami (funciona com bloqueador).
//
// Eventos (todos com { page }):
//   cta-whatsapp   { ref, channel, label }   clique num botão do bot
//   cta-entrar     { label }
//   scroll-depth   { depth: 25|50|75|100 }   uma vez por página
//   section-view   { section }               [data-track-section] visível
//   faq-open       { question }
//   video-*, demo-view                       ver hero_video / whatsapp_demo

const FIRST_TOUCH_KEY = "ez_first_touch"
const FIRST_TOUCH_TTL = 30 * 24 * 60 * 60 * 1000

const REFERRER_CHANNELS = [
  [/gemini\.google\.com$/, "gemini"], [/(^|\.)google\./, "google"], [/(^|\.)bing\.com$/, "bing"], [/duckduckgo\.com$/, "duckduckgo"],
  [/(^|\.)yahoo\./, "yahoo"], [/ecosia\.org$/, "ecosia"], [/instagram\.com$/, "instagram"],
  [/(^|\.)(facebook|fb)\.com$|^l\.facebook\.com$/, "facebook"], [/(^|\.)(t\.co|twitter\.com|x\.com)$/, "x"],
  [/linkedin\.com$/, "linkedin"], [/youtube\.com$|youtu\.be$/, "youtube"], [/tiktok\.com$/, "tiktok"],
  [/whatsapp\.com$/, "whatsapp"], [/chatgpt\.com$|openai\.com$/, "chatgpt"], [/perplexity\.ai$/, "perplexity"],
  [/claude\.ai$/, "claude"]
]

export function track(name, data = {}) {
  try {
    window.umami?.track(name, { page: location.pathname, ...data })
  } catch (_) {
    // analytics nunca pode quebrar a página
  }
}

// ── Canal da visita ──────────────────────────────────────────────────────
function slug(value) {
  return String(value).toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 30)
}

function detectChannel() {
  const params = new URLSearchParams(location.search)
  const utm = params.get("utm_campaign") || params.get("utm_source")
  if (utm) return slug(utm)
  if (params.has("gclid")) return "google-ads"
  if (params.has("fbclid")) return "meta-ads"

  let host = ""
  try { host = new URL(document.referrer).hostname.replace(/^www\./, "") } catch (_) { return null }
  if (!host || host === location.hostname.replace(/^www\./, "")) return null

  const known = REFERRER_CHANNELS.find(([pattern]) => pattern.test(host))
  return known ? known[1] : slug(host.split(".").slice(-2, -1)[0] || host)
}

// Primeira visita com origem conhecida nos últimos 30 dias (acesso direto
// depois de vir do Google continua contando como Google).
function visitChannel() {
  let stored = null
  try { stored = JSON.parse(localStorage.getItem(FIRST_TOUCH_KEY)) } catch (_) { /* sem storage */ }
  if (stored?.channel && Date.now() - stored.at < FIRST_TOUCH_TTL) return stored.channel

  const channel = detectChannel()
  if (channel) {
    try { localStorage.setItem(FIRST_TOUCH_KEY, JSON.stringify({ channel, at: Date.now() })) } catch (_) { /* ok */ }
  }
  return channel
}

const channel = visitChannel()

// ── Cliques ──────────────────────────────────────────────────────────────
const CODE = /%5B([a-z0-9-]+)%5D/i

document.addEventListener("click", (event) => {
  const link = event.target.closest?.("a[href]")
  if (!link) return
  const href = link.getAttribute("href")

  if (href.includes("wa.me/")) {
    const ref = href.match(CODE)?.[1]
    if (ref && channel && !href.includes("~")) link.setAttribute("href", href.replace(CODE, `%5B${ref}~${channel}%5D`))
    track("cta-whatsapp", { ref: ref || "sem-codigo", channel: channel || "direto", label: link.textContent.trim().slice(0, 40) })
  } else if (href.startsWith("/app/entrar")) {
    track("cta-entrar", { label: link.textContent.trim().slice(0, 40) })
  }
}, true)

// FAQ (<details>): "toggle" não borbulha, por isso a captura
document.addEventListener("toggle", (event) => {
  const details = event.target
  if (details.tagName !== "DETAILS" || !details.open) return
  track("faq-open", { question: details.querySelector("summary")?.textContent.trim().slice(0, 60) })
}, true)

// ── Por página: rolagem e seções vistas ─────────────────────────────────
let pageCleanup = null

function setupPage() {
  pageCleanup?.()

  const reached = new Set()
  const onScroll = () => {
    const doc = document.documentElement
    const max = doc.scrollHeight - innerHeight
    const percent = max > 0 ? (scrollY / max) * 100 : 100
    for (const depth of [25, 50, 75, 100]) {
      if (percent >= depth - 2 && !reached.has(depth)) {
        reached.add(depth)
        track("scroll-depth", { depth })
      }
    }
  }
  let ticking = false
  const onScrollThrottled = () => {
    if (ticking) return
    ticking = true
    requestAnimationFrame(() => { ticking = false; onScroll() })
  }
  addEventListener("scroll", onScrollThrottled, { passive: true })

  const observer = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue
      track("section-view", { section: entry.target.dataset.trackSection })
      observer.unobserve(entry.target)
    }
  }, { threshold: 0.4 })
  document.querySelectorAll("[data-track-section]").forEach((el) => observer.observe(el))

  pageCleanup = () => {
    removeEventListener("scroll", onScrollThrottled)
    observer.disconnect()
  }
}

document.addEventListener("turbo:load", setupPage)
