import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "title", "statusText", "playBtn", "pauseBtn", "volumeLevel", "qualityBadge", "recoveryBadge"]
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
    this.fetchVolume()
    this.qualityBadgeTarget.textContent = ""
    this.recoveryBadgeTarget.textContent = ""
    this.scheduleForceHD()
    this.scheduleErrorRecovery()
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
    const res = await this.postJSON("/player/volume_up")
    this.updateVolumeDisplay(res.volume)
  }

  async volumeDown() {
    const res = await this.postJSON("/player/volume_down")
    this.updateVolumeDisplay(res.volume)
  }

  async seekForward() {
    await this.postJSON("/player/seek_forward")
  }

  async seekBackward() {
    await this.postJSON("/player/seek_backward")
  }

  async seekForward60() {
    await this.postJSON("/player/seek_forward_60")
  }

  async seekBackward60() {
    await this.postJSON("/player/seek_backward_60")
  }

  async restart() {
    await this.postJSON("/player/restart")
  }

  async forceHD() {
    const res = await this.postJSON("/player/force_hd")
    if (res.quality && res.quality.success) {
      this.qualityBadgeTarget.textContent = res.quality.quality || "HD"
    } else {
      this.qualityBadgeTarget.textContent = ""
    }
  }

  scheduleForceHD(attempt = 0) {
    const maxAttempts = 5
    const delay = attempt === 0 ? 5000 : 3000
    setTimeout(async () => {
      try {
        const res = await this.postJSON("/player/force_hd")
        if (res.quality && res.quality.success) {
          this.qualityBadgeTarget.textContent = res.quality.quality || "HD"
        } else if (attempt < maxAttempts) {
          this.scheduleForceHD(attempt + 1)
        }
      } catch {
        if (attempt < maxAttempts) this.scheduleForceHD(attempt + 1)
      }
    }, delay)
  }

  scheduleErrorRecovery(attempt = 0) {
    const maxAttempts = 5
    const delay = attempt === 0 ? 8000 : 4000
    setTimeout(async () => {
      try {
        const res = await this.postJSON("/player/inject_error_recovery")
        if (res.recovery && res.recovery.success) {
          this.recoveryBadgeTarget.textContent = "ERR-REC"
        } else if (attempt < maxAttempts) {
          this.scheduleErrorRecovery(attempt + 1)
        }
      } catch {
        if (attempt < maxAttempts) this.scheduleErrorRecovery(attempt + 1)
      }
    }, delay)
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

  async fetchVolume() {
    try {
      const resp = await fetch("/player/volume")
      const data = await resp.json()
      this.updateVolumeDisplay(data.volume)
    } catch {
      this.volumeLevelTarget.textContent = ""
    }
  }

  updateVolumeDisplay(volume) {
    if (volume == null) return
    const pct = Math.round(volume * 100)
    this.volumeLevelTarget.textContent = `Volume: ${pct}%`
  }

  async postJSON(url) {
    const resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" }
    })
    return resp.json()
  }
}
