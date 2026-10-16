import { Controller } from "@hotwired/stimulus"

// Plays the landing hero "video" — the sales script as an HTML animation:
// hook → pain → turn → forward demo → Pro demo → proof → CTA, on a loop.
// Each scene is a layer (.hv-scene); its beats ([data-beat]) are revealed by
// adding .is-shown. Scenes 4 and 5 drive the phone demos (whatsapp-demo).
// Runs only while on screen; reduced-motion users get static scenes they can
// flip through with the progress segments.
const CANCELLED = Symbol("cancelled")
const EXTRA_STATES = ["is-gone", "is-playing", "is-rewind"]

export default class extends Controller {
  static targets = ["stage", "scene", "segment", "toggle", "voice", "forwardDemo", "proDemo"]
  static values = { pauseLabel: String, playLabel: String }

  connect() {
    this.runId = 0
    this.index = 0
    this.paused = false
    this.visible = false
    // duration: estimate used only to pace the progress bar
    this.scenes = [
      { duration: 3800, run: (wait) => this.hook(wait) },
      { duration: 7600, run: (wait) => this.pain(wait) },
      { duration: 2800, run: (wait) => this.turn(wait) },
      { duration: 12000, run: (wait) => this.forward(wait) },
      { duration: 9500, run: (wait) => this.pro(wait) },
      { duration: 3200, run: (wait) => this.proof(wait) },
      { duration: 5800, run: (wait) => this.cta(wait) }
    ]

    this.reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (this.reduced) {
      this.toggleTarget.hidden = true
      this.showStatic(3)
      return
    }

    this.observer = new IntersectionObserver(([entry]) => {
      this.visible = entry.isIntersecting
      this.visible ? this.play() : this.stop()
    }, { threshold: 0.4 })
    this.observer.observe(this.element)

    this.onVisibilityChange = () => document.hidden ? this.stop() : this.visible && this.play()
    document.addEventListener("visibilitychange", this.onVisibilityChange)
  }

  disconnect() {
    this.stop()
    this.observer?.disconnect()
    if (this.onVisibilityChange) document.removeEventListener("visibilitychange", this.onVisibilityChange)
  }

  // ── Controls ─────────────────────────────────────────────────────────
  toggle() {
    this.paused = !this.paused
    this.paused ? this.stop() : this.play()
    this.syncToggle()
  }

  jump({ params: { index } }) {
    if (this.reduced) return this.showStatic(index)
    this.stop()
    this.index = index
    this.paused = false
    this.syncToggle()
    this.play()
  }

  syncToggle() {
    this.stageTarget.classList.toggle("is-paused", this.paused)
    this.toggleTarget.setAttribute("aria-label", this.paused ? this.playLabelValue : this.pauseLabelValue)
    this.toggleTarget.querySelector("i").className = this.paused ? "ph-fill ph-play" : "ph-fill ph-pause"
  }

  // Phone demos report their step; captions follow them
  demoStep({ detail: { index } }) {
    if (index !== 2) return
    if (this.index === 3) this.show("forward-counter")
    if (this.index === 4) this.only("pro-caption", "pro-2")
  }

  // ── Playback ─────────────────────────────────────────────────────────
  play() {
    if (this.running || this.paused) return
    this.running = true
    this.loop(++this.runId)
  }

  stop() {
    this.running = false
    this.runId++
    for (const demo of this.demos()) demo?.stop()
  }

  async loop(run) {
    const wait = (ms) => this.wait(ms, run)
    try {
      while (true) {
        for (; this.index < this.scenes.length; this.index++) {
          this.activate(this.index)
          await this.scenes[this.index].run(wait)
        }
        this.index = 0
      }
    } catch (error) {
      if (error !== CANCELLED) throw error
    }
  }

  activate(index) {
    const scene = this.sceneTargets[index]
    this.sceneTargets.forEach((el, i) => el.classList.toggle("is-active", i === index))
    this.stageTarget.classList.toggle("is-dark", scene.hasAttribute("data-dark"))
    for (const beat of scene.querySelectorAll("[data-beat]")) beat.classList.remove("is-shown", ...EXTRA_STATES)

    this.segmentTargets.forEach((segment, i) => {
      segment.classList.remove("is-active")
      segment.classList.toggle("is-done", i < index)
      if (i === index) segment.style.setProperty("--dur", `${this.scenes[i].duration}ms`)
    })
    // Restart the fill animation even when re-activating the same segment
    this.segmentTargets[index].offsetWidth
    this.segmentTargets[index].classList.add("is-active")
  }

  showStatic(index) {
    this.index = index
    this.activate(index)
    for (const beat of this.sceneTargets[index].querySelectorAll("[data-beat]")) beat.classList.add("is-shown")
    for (const group of ["pain-caption", "pro-caption"]) {
      const captions = this.element.querySelectorAll(`[data-beat-group="${group}"]`)
      captions.forEach((el, i) => el.classList.toggle("is-shown", i === captions.length - 1))
    }
    this.element.querySelector('[data-beat="pain-cards"]').classList.add("is-gone")
  }

  // ── Scenes ───────────────────────────────────────────────────────────
  async hook(wait) {
    await wait(400)
    for (let i = 0; i < 4; i++) {
      this.show(`notif-${i}`)
      await wait(350)
    }
    await wait(200)
    this.show("hook-title")
    await wait(1900)
  }

  async pain(wait) {
    for (let i = 1; i <= 3; i++) {
      this.only("pain-caption", `pain-${i}`)
      this.show(`card-${i}`)
      await wait(1300)
    }
    this.only("pain-caption", "pain-4")
    this.beat("pain-cards").classList.add("is-gone")
    this.show("pain-voice")
    await wait(400)
    this.voiceTarget.classList.add("is-playing")
    await wait(1800)
    this.voiceTarget.classList.replace("is-playing", "is-rewind")
    await wait(1300)
  }

  async turn(wait) {
    await wait(500)
    this.show("turn-strike")
    await wait(450)
    this.show("turn-word")
    await wait(600)
    this.show("turn-logo")
    await wait(1200)
  }

  async forward(wait) {
    await this.playDemo(this.forwardDemoTarget, wait)
    await wait(1500)
  }

  async pro(wait) {
    this.only("pro-caption", "pro-1")
    await this.playDemo(this.proDemoTarget, wait)
    await wait(1600)
  }

  async proof(wait) {
    await wait(250)
    for (let i = 1; i <= 3; i++) {
      this.show(`proof-${i}`)
      await wait(350)
    }
    await wait(1900)
  }

  async cta(wait) {
    await wait(200)
    this.show("cta-title")
    await wait(300)
    this.show("cta-body")
    await wait(250)
    this.show("cta-button")
    await wait(5000)
  }

  // ── Helpers ──────────────────────────────────────────────────────────
  async playDemo(container, wait) {
    const demo = this.demoIn(container)
    demo.reset()
    await wait(350)
    await demo.playOnce()
    await wait(0) // throws if we were stopped while the demo played
  }

  demos() {
    return [this.forwardDemoTarget, this.proDemoTarget].map((container) => this.demoIn(container))
  }

  demoIn(container) {
    return this.application.getControllerForElementAndIdentifier(container.querySelector(".wa-demo"), "whatsapp-demo")
  }

  beat(name) {
    return this.element.querySelector(`[data-beat="${name}"]`)
  }

  show(name) {
    this.beat(name).classList.add("is-shown")
  }

  only(group, name) {
    for (const el of this.element.querySelectorAll(`[data-beat-group="${group}"]`)) {
      el.classList.toggle("is-shown", el.dataset.beat === name)
    }
  }

  wait(ms, run) {
    return new Promise((resolve, reject) => {
      setTimeout(() => (run === this.runId ? resolve() : reject(CANCELLED)), ms)
    })
  }
}
