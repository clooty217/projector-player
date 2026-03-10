import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "title", "statusText", "playBtn", "pauseBtn"]
  static outlets = ["search"]

  connect() {
    this.paused = false
  }

  show(title) {
    this.titleTarget.textContent = title
    this.statusTextTarget.textContent = "Now Playing"
    this.paused = false
    this.syncButtons()
    this.panelTarget.classList.add("visible")
  }

  hide() {
    this.panelTarget.classList.remove("visible")
    this.searchOutlet.showBrowse()
  }

  async pause() {
    this.statusTextTarget.textContent = "Pausing..."
    const res = await this.postJSON("/player/pause")
    if (res.status === "paused") {
      this.paused = true
      this.syncButtons()
      this.statusTextTarget.textContent = "Paused"
    } else {
      this.statusTextTarget.textContent = res.message || "Pause failed"
    }
  }

  async resume() {
    this.statusTextTarget.textContent = "Resuming..."
    const res = await this.postJSON("/player/resume")
    if (res.status === "resumed") {
      this.paused = false
      this.syncButtons()
      this.statusTextTarget.textContent = "Now Playing"
    } else {
      this.statusTextTarget.textContent = res.message || "Resume failed"
    }
  }

  async volumeUp() {
    await this.postJSON("/player/volume_up")
  }

  async volumeDown() {
    await this.postJSON("/player/volume_down")
  }

  async exit() {
    this.statusTextTarget.textContent = "Stopping..."
    await this.postJSON("/player/exit")
    this.hide()
  }

  syncButtons() {
    this.playBtnTarget.classList.toggle("hidden", !this.paused)
    this.pauseBtnTarget.classList.toggle("hidden", this.paused)
  }

  async postJSON(url) {
    const resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" }
    })
    return resp.json()
  }
}
