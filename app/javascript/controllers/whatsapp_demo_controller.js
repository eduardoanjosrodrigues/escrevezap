import { Controller } from "@hotwired/stimulus"
import { track } from "../analytics"

// Plays the landing-page WhatsApp demos on a loop. Two scenarios:
//   forward  — long-press an audio, forward it to EscreveZap, read the reply
//   reaction — (Pro) react to an audio, the transcription appears in the chat
// Only toggles CSS state classes (see whatsapp_demo.css). Runs while the demo
// is on screen; reduced-motion users get the final frame without animation.
// With autoplay off (inside the hero video) a parent drives it via playOnce(),
// and speed > 1 shortens the pauses between beats (not the motion itself).
const CANCELLED = Symbol("cancelled")
const SCREEN_FLAGS = ["is-selecting", "is-forwarding", "is-bot", "is-fading"]
const STATE_CLASSES = ["is-checked", "is-shown", "is-tapped", "is-selected", "is-delivered", "is-read"]

export default class extends Controller {
  static targets = [
    "screen", "finger", "contactHeader", "botHeader", "overlay", "badge", "step", "toggle", "reveal",
    "incomingAudio", "incomingText", "audioBubble", "audioCheck", "menu", "forwardItem", "ticks",
    "forwardButton", "botContact", "botCheck", "sendBar", "sendButton",
    "sentAudio", "typing", "reply", "replyFooter",
    "reactionEmoji", "reactionBadge"
  ]
  static values = {
    scenario: { type: String, default: "forward" },
    autoplay: { type: Boolean, default: true },
    speed: { type: Number, default: 1 },
    pauseLabel: String,
    playLabel: String
  }

  connect() {
    this.runId = 0
    this.paused = false
    this.visible = false
    this.words = new Map(this.revealTargets.map((el) => [el, this.buildWords(el.dataset.text)]))

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.showFinalFrame()
      this.toggleTarget.hidden = true
      return
    }
    if (!this.autoplayValue) {
      this.toggleTarget.hidden = true
      return
    }

    this.observer = new IntersectionObserver(([entry]) => {
      this.visible = entry.isIntersecting
      this.visible ? this.play() : this.stop()
    }, { threshold: 0.35 })
    this.observer.observe(this.element)

    this.onVisibilityChange = () => document.hidden ? this.stop() : this.visible && this.play()
    document.addEventListener("visibilitychange", this.onVisibilityChange)
  }

  disconnect() {
    this.stop()
    this.observer?.disconnect()
    if (this.onVisibilityChange) document.removeEventListener("visibilitychange", this.onVisibilityChange)
  }

  toggle() {
    this.paused = !this.paused
    this.paused ? this.stop() : this.play()
    this.toggleTarget.setAttribute("aria-label", this.paused ? this.playLabelValue : this.pauseLabelValue)
    this.toggleTarget.querySelector("i").className = this.paused ? "ph-fill ph-play" : "ph-fill ph-pause"
  }

  play() {
    if (this.running || this.paused) return
    if (!this.viewTracked) {
      this.viewTracked = true
      track("demo-view", { scenario: this.scenarioValue })
    }
    this.running = true
    this.loop(++this.runId)
  }

  stop() {
    this.running = false
    this.runId++
  }

  // Plays the scenario once (used by the hero video). Resolves when it ends
  // or when stop() cancels it.
  async playOnce() {
    this.stop()
    const run = ++this.runId
    this.running = true
    try {
      await this.playScenario(this.waiter(run))
    } catch (error) {
      if (error !== CANCELLED) throw error
    } finally {
      if (run === this.runId) this.running = false
    }
  }

  async loop(run) {
    const wait = this.waiter(run)
    try {
      while (true) {
        await this.playScenario(wait)
        await wait(4500)
        this.screenTarget.classList.add("is-fading")
        this.badgeTarget.classList.remove("is-shown")
        await wait(600)
      }
    } catch (error) {
      if (error !== CANCELLED) throw error
    }
  }

  async playScenario(wait) {
    this.reset()
    await (this.scenarioValue === "reaction" ? this.reactionScript(wait) : this.forwardScript(wait))
    this.badgeTarget.classList.add("is-shown")
  }

  // wait() is scaled by speed; wait.raw() is for beats that must match a CSS
  // transition (finger moves, taps). When sped up (inside the hero video),
  // hero_video.css makes those transitions 1.5x faster, so raw waits follow.
  waiter(run) {
    const wait = (ms) => this.wait(ms / this.speedValue, run)
    wait.raw = (ms) => this.wait(ms / Math.min(this.speedValue, 1.5), run)
    return wait
  }

  // ── Scripts ──────────────────────────────────────────────────────────
  async forwardScript(wait) {
    await this.receiveAudio(wait)
    this.enter(this.incomingTextTarget)
    await wait(1000)

    // Long-press the audio → context menu → Encaminhar
    this.setStep(0)
    await this.longPressAudio(wait)
    await wait(1100)
    await this.moveFinger(this.forwardItemTarget, wait)
    await this.tap(this.forwardItemTarget, wait)
    this.unlift()
    this.screenTarget.classList.add("is-selecting")
    this.audioCheckTarget.classList.add("is-checked")
    await wait(800)

    // Forward sheet → pick EscreveZap → send
    this.setStep(1)
    await this.moveFinger(this.forwardButtonTarget, wait)
    await this.tap(this.forwardButtonTarget, wait)
    this.screenTarget.classList.add("is-forwarding")
    await wait(800)
    await this.moveFinger(this.botContactTarget, wait, { x: -30 })
    await this.tap(this.botContactTarget, wait)
    this.botCheckTarget.classList.add("is-checked")
    this.sendBarTarget.classList.add("is-shown")
    await wait(600)
    await this.moveFinger(this.sendButtonTarget, wait)
    await this.tap(this.sendButtonTarget, wait)
    this.fingerTarget.classList.remove("is-shown")

    // EscreveZap chat: audio delivered, bot types, transcription arrives
    this.screenTarget.classList.remove("is-forwarding", "is-selecting")
    this.screenTarget.classList.add("is-bot")
    await wait(450)
    this.enter(this.sentAudioTarget)
    await this.deliver(wait)
    this.setStep(2)
    await wait(300)
    this.botHeaderTarget.dataset.status = "typing"
    this.enter(this.typingTarget)
    await wait(1600)
    this.typingTarget.classList.add("is-pending")
    this.enter(this.replyTarget)
    await this.revealWords(wait, 55)
    this.replyFooterTarget.classList.remove("is-pending")
    this.scrollToBottom(this.replyTarget)
    this.botHeaderTarget.dataset.status = "online"
    await wait(400)
  }

  async reactionScript(wait) {
    await this.receiveAudio(wait)
    await wait(500)

    // Long-press the audio → tap 👍 in the reaction bar
    this.setStep(0)
    await this.longPressAudio(wait)
    await wait(900)
    await this.moveFinger(this.reactionEmojiTarget, wait)
    await this.tap(this.reactionEmojiTarget, wait)
    this.reactionEmojiTarget.classList.add("is-selected")
    await wait(350)
    this.unlift()
    this.fingerTarget.classList.remove("is-shown")
    await wait(250)
    this.reactionBadgeTarget.classList.add("is-shown")
    await wait(900)

    // EscreveZap replies to the audio from the user's own number…
    this.setStep(1)
    this.enter(this.replyTarget)
    this.scrollToBottom(this.replyTarget)
    await this.deliver(wait)
    await wait(1400)

    // …and edits that reply into the summary + full transcription
    this.setStep(2)
    this.replyTarget.classList.add("is-done")
    await this.revealWords(wait, 40)
    await wait(400)
  }

  // ── Shared beats ─────────────────────────────────────────────────────
  async receiveAudio(wait) {
    await wait(800)
    this.contactHeaderTarget.dataset.status = "recording"
    await wait(1600)
    this.contactHeaderTarget.dataset.status = "online"
    this.enter(this.incomingAudioTarget)
    await wait(700)
  }

  async longPressAudio(wait) {
    this.fingerTarget.classList.add("is-shown")
    await this.moveFinger(this.audioBubbleTarget, wait, { x: -40 })
    this.incomingAudioTarget.classList.add("is-pressing")
    this.fingerTarget.classList.add("is-holding")
    await wait.raw(700)
    this.fingerTarget.classList.remove("is-holding")
    this.incomingAudioTarget.classList.remove("is-pressing")
    this.lift()
  }

  async deliver(wait) {
    await wait(500)
    this.ticksTarget.classList.add("is-delivered")
    await wait(500)
    this.ticksTarget.classList.add("is-read")
  }

  async revealWords(wait, delay) {
    for (const el of this.revealTargets) el.replaceChildren()
    for (const el of this.revealTargets) {
      for (const word of this.words.get(el)) {
        el.append(word)
        this.scrollToBottom(el)
        await wait(delay)
      }
    }
  }

  // ── State helpers ────────────────────────────────────────────────────
  reset() {
    this.screenTarget.classList.remove(...SCREEN_FLAGS)
    for (const row of this.element.querySelectorAll("[data-demo-row]")) {
      row.classList.remove("is-in", "is-pressing", "is-lifted", "is-done")
      row.classList.add("is-pending")
    }
    for (const el of this.element.querySelectorAll("[data-demo-later]")) el.classList.add("is-pending")
    for (const name of STATE_CLASSES) {
      for (const el of this.screenTarget.querySelectorAll(`.${name}`)) el.classList.remove(name)
    }
    this.badgeTarget.classList.remove("is-shown")
    for (const header of this.element.querySelectorAll(".wa-header")) header.dataset.status = "online"
    for (const body of this.element.querySelectorAll(".wa-body")) body.scrollTop = 0

    const finger = this.fingerTarget
    finger.className = "wa-finger"
    finger.style.transition = "none"
    finger.style.transform = `translate(${this.screenTarget.offsetWidth / 2}px, ${this.screenTarget.offsetHeight - 40}px)`
    finger.offsetWidth // commit the jump before transitions come back
    finger.style.transition = ""
    this.setStep(-1)
  }

  showFinalFrame() {
    if (this.scenarioValue === "reaction") {
      this.enter(this.incomingAudioTarget)
      this.reactionBadgeTarget.classList.add("is-shown")
      this.replyTarget.classList.add("is-done")
    } else {
      this.screenTarget.classList.add("is-bot")
      this.enter(this.sentAudioTarget)
      this.replyFooterTarget.classList.remove("is-pending")
    }
    this.enter(this.replyTarget)
    this.ticksTarget.classList.add("is-read")
    this.badgeTarget.classList.add("is-shown")
    this.setStep(2)
    this.scrollToBottom(this.replyTarget)
  }

  enter(row) {
    row.classList.remove("is-pending")
    row.classList.add("is-in")
  }

  // Lifts the pressed bubble and shifts it up so the menu fits on screen
  lift() {
    const row = this.incomingAudioTarget
    const screenRect = this.screenTarget.getBoundingClientRect()
    const rowRect = row.getBoundingClientRect()
    const menuBottom = (rowRect.bottom - screenRect.top) / this.scale() + 8 + this.menuTarget.offsetHeight
    const limit = this.screenTarget.offsetHeight - 36
    row.style.setProperty("--wa-lift", `${Math.min(0, limit - menuBottom)}px`)
    this.overlayTarget.classList.add("is-shown")
    row.classList.add("is-lifted")
  }

  unlift() {
    this.overlayTarget.classList.remove("is-shown")
    this.incomingAudioTarget.classList.remove("is-lifted")
  }

  setStep(index) {
    this.stepTargets.forEach((step, i) => {
      step.classList.toggle("is-active", i === index)
      i === index ? step.setAttribute("aria-current", "step") : step.removeAttribute("aria-current")
    })
    this.dispatch("step", { detail: { index } })
  }

  scrollToBottom(element) {
    const body = element.closest(".wa-body")
    body.scrollTop = body.scrollHeight
  }

  // ── Finger ───────────────────────────────────────────────────────────
  async moveFinger(element, wait, offset = {}) {
    const scale = this.scale()
    const screenRect = this.screenTarget.getBoundingClientRect()
    const rect = element.getBoundingClientRect()
    const x = (rect.left + rect.width / 2 - screenRect.left) / scale + (offset.x || 0)
    const y = (rect.top + rect.height / 2 - screenRect.top) / scale + (offset.y || 0)
    this.fingerTarget.style.transform = `translate(${x}px, ${y}px)`
    await wait.raw(650)
  }

  async tap(element, wait) {
    this.fingerTarget.classList.add("is-tapping")
    element.classList.add("is-tapped")
    await wait.raw(260)
    this.fingerTarget.classList.remove("is-tapping")
    element.classList.remove("is-tapped")
    await wait.raw(140)
  }

  // CSS zoom/transforms on ancestors make rects differ from layout px
  scale() {
    return this.screenTarget.getBoundingClientRect().width / this.screenTarget.offsetWidth || 1
  }

  wait(ms, run) {
    return new Promise((resolve, reject) => {
      setTimeout(() => (run === this.runId ? resolve() : reject(CANCELLED)), ms)
    })
  }

  buildWords(text) {
    return text.split(" ").map((word) => {
      const span = document.createElement("span")
      span.className = "wa-word"
      span.textContent = `${word} `
      return span
    })
  }
}
