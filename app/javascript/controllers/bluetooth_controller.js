import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "list", "sinkList", "scanBtn", "scanStatus"]

  connect() {
    this.scanning = false
  }

  open() {
    this.modalTarget.classList.add("visible")
    this.loadSinks()
    this.loadDevices()
  }

  close() {
    this.modalTarget.classList.remove("visible")
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) this.close()
  }

  // ── Audio Sinks ──

  async loadSinks() {
    this.sinkListTarget.innerHTML = '<p class="loading">Loading audio outputs...</p>'
    const sinks = await this.getJSON("/audio/sinks")
    this.renderSinks(sinks)
  }

  async setSink(event) {
    const btn = event.currentTarget
    const sinkName = btn.dataset.sink
    btn.disabled = true
    btn.textContent = "Switching..."

    const result = await this.postJSON("/audio/set_sink", { sink: sinkName })
    if (result.success) {
      this.loadSinks()
    } else {
      btn.textContent = "Failed"
      setTimeout(() => { btn.textContent = "Select"; btn.disabled = false }, 2000)
    }
  }

  renderSinks(sinks) {
    if (!sinks || sinks.length === 0) {
      this.sinkListTarget.innerHTML = '<p class="no-results">No audio outputs found.</p>'
      return
    }

    this.sinkListTarget.innerHTML = sinks.map(s => {
      const activeClass = s.default ? "bt-connected" : ""
      const statusLabel = s.default ? "Active" : s.state
      const actionBtn = s.default
        ? `<button class="bt-action bt-action--disconnect" disabled>Active</button>`
        : `<button class="bt-action bt-action--connect" data-action="click->bluetooth#setSink" data-sink="${s.name}">Select</button>`

      return `
        <div class="bt-device ${activeClass}">
          <div class="bt-device-info">
            <strong>${s.description}</strong>
            <span class="bt-device-status">${statusLabel}</span>
          </div>
          <div class="bt-device-actions">
            ${actionBtn}
          </div>
        </div>`
    }).join("")
  }

  // ── Bluetooth Devices ──

  async loadDevices() {
    this.listTarget.innerHTML = '<p class="loading">Loading paired devices...</p>'
    const devices = await this.getJSON("/bluetooth/devices")
    this.renderDevices(devices)
  }

  async scan() {
    if (this.scanning) return
    this.scanning = true
    this.scanBtnTarget.disabled = true
    this.scanStatusTarget.textContent = "Scanning..."

    const devices = await this.postJSON("/bluetooth/scan", { seconds: 8 })
    this.renderDevices(devices)

    this.scanning = false
    this.scanBtnTarget.disabled = false
    this.scanStatusTarget.textContent = ""
  }

  async connectDevice(event) {
    const btn = event.currentTarget
    const mac = btn.dataset.mac
    btn.disabled = true
    btn.textContent = "Connecting..."

    const result = await this.postJSON("/bluetooth/connect", { mac })
    if (result.success) {
      btn.textContent = "Connected"
      this.loadDevices()
      this.loadSinks()
    } else {
      btn.textContent = "Failed"
      setTimeout(() => { btn.textContent = "Connect"; btn.disabled = false }, 2000)
    }
  }

  async disconnectDevice(event) {
    const btn = event.currentTarget
    const mac = btn.dataset.mac
    btn.disabled = true
    btn.textContent = "Disconnecting..."

    await this.postJSON("/bluetooth/disconnect", { mac })
    this.loadDevices()
    this.loadSinks()
  }

  async removeDevice(event) {
    const btn = event.currentTarget
    const mac = btn.dataset.mac
    btn.disabled = true
    btn.textContent = "Removing..."

    await this.postJSON("/bluetooth/remove", { mac })
    this.loadDevices()
    this.loadSinks()
  }

  renderDevices(devices) {
    if (!devices || devices.length === 0) {
      this.listTarget.innerHTML = '<p class="no-results">No devices found. Try scanning.</p>'
      return
    }

    this.listTarget.innerHTML = devices.map(d => {
      const statusClass = d.connected ? "bt-connected" : ""
      const statusLabel = d.connected ? "Connected" : (d.paired ? "Paired" : "Available")

      const actions = d.connected
        ? `<button class="bt-action bt-action--disconnect" data-action="click->bluetooth#disconnectDevice" data-mac="${d.mac}">Disconnect</button>`
        : `<button class="bt-action bt-action--connect" data-action="click->bluetooth#connectDevice" data-mac="${d.mac}">Connect</button>`

      const removeBtn = d.paired
        ? `<button class="bt-action bt-action--remove" data-action="click->bluetooth#removeDevice" data-mac="${d.mac}">Remove</button>`
        : ""

      return `
        <div class="bt-device ${statusClass}">
          <div class="bt-device-info">
            <strong>${d.name || d.mac}</strong>
            <span class="bt-device-mac">${d.mac}</span>
            <span class="bt-device-status">${statusLabel}</span>
          </div>
          <div class="bt-device-actions">
            ${actions}
            ${removeBtn}
          </div>
        </div>`
    }).join("")
  }

  async getJSON(url) {
    const resp = await fetch(url)
    return resp.json()
  }

  async postJSON(url, body = {}) {
    const resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    })
    return resp.json()
  }
}
