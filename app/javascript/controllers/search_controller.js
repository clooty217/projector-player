import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "grid", "pageInfo", "prevBtn", "nextBtn", "typeToggle", "heading", "browse"]
  static outlets = ["remote"]

  connect() {
    this.page = 1
    this.totalPages = 1
    this.query = ""
    this.mediaType = "movie"
    this.debounceTimer = null
    this.loadTrending()
    this.checkActiveSession()
  }

  async checkActiveSession() {
    try {
      const res = await fetch("/player/status").then(r => r.json())
      if (res.playing) {
        this.browseTarget.classList.add("hidden")
        this.remoteOutlet.show(res.title || "Unknown")
      }
    } catch {}
  }

  setType(event) {
    const type = event.currentTarget.dataset.type
    if (type === this.mediaType) return

    this.mediaType = type
    this.page = 1

    this.typeToggleTargets.forEach(btn => {
      btn.classList.toggle("active", btn.dataset.type === type)
    })

    if (this.query.length > 0) {
      this.performSearch()
    } else {
      this.loadTrending()
    }
  }

  search() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => {
      this.query = this.inputTarget.value.trim()
      this.page = 1
      if (this.query.length > 0) {
        this.performSearch()
      } else {
        this.loadTrending()
      }
    }, 350)
  }

  prevPage() {
    if (this.page > 1) {
      this.page--
      this.fetchCurrentView()
    }
  }

  nextPage() {
    if (this.page < this.totalPages) {
      this.page++
      this.fetchCurrentView()
    }
  }

  async loadTrending() {
    this.headingTarget.textContent = "Trending Movies"
    const data = await this.fetchJSON(`/tmdb/trending?page=${this.page}`)
    this.renderResults(data)
  }

  async performSearch() {
    const label = this.mediaType === "tv" ? "TV Shows" : "Movies"
    this.headingTarget.textContent = `Search: "${this.query}" (${label})`
    const data = await this.fetchJSON(
      `/tmdb/search?query=${encodeURIComponent(this.query)}&page=${this.page}&type=${this.mediaType}`
    )
    this.renderResults(data)
  }

  fetchCurrentView() {
    if (this.query.length > 0) {
      this.performSearch()
    } else {
      this.loadTrending()
    }
  }

  async fetchJSON(url) {
    const resp = await fetch(url)
    return resp.json()
  }

  renderResults(data) {
    const results = data.results || []
    this.totalPages = data.total_pages || 1
    this.updatePagination()

    if (results.length === 0) {
      this.gridTarget.innerHTML = '<p class="no-results">No results found.</p>'
      return
    }

    this.gridTarget.innerHTML = results.map(item => this.cardHTML(item)).join("")
  }

  cardHTML(item) {
    const title = item.title || item.name || "Untitled"
    const year = (item.release_date || item.first_air_date || "").slice(0, 4)
    const rating = item.vote_average ? item.vote_average.toFixed(1) : "N/A"
    const poster = item.poster_path
      ? `https://image.tmdb.org/t/p/w342${item.poster_path}`
      : ""
    const mediaType = item.title ? "movie" : "tv"
    const posterImg = poster
      ? `<img src="${poster}" alt="${title}" loading="lazy">`
      : `<div class="no-poster"><span>${title}</span></div>`

    if (mediaType === "tv") {
      return `
        <div class="card" data-action="click->tv-detail#open"
             data-tv-id="${item.id}" data-tv-name="${this.escapeAttr(title)}">
          <div class="card-poster">${posterImg}</div>
          <div class="card-info">
            <h3>${title}</h3>
            <div class="card-meta">
              <span class="year">${year}</span>
              <span class="rating">&#9733; ${rating}</span>
              <span class="badge">TV</span>
            </div>
          </div>
        </div>`
    }

    return `
      <div class="card" data-action="click->search#playMovie"
           data-tmdb-id="${item.id}" data-title="${this.escapeAttr(title)}">
        <div class="card-poster">${posterImg}</div>
        <div class="card-info">
          <h3>${title}</h3>
          <div class="card-meta">
            <span class="year">${year}</span>
            <span class="rating">&#9733; ${rating}</span>
          </div>
        </div>
      </div>`
  }

  async playMovie(event) {
    const card = event.currentTarget
    const tmdbId = card.dataset.tmdbId
    const title = card.dataset.title
    card.classList.add("playing")

    const res = await fetch("/player/play", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ tmdb_id: tmdbId, media_type: "movie", title: title })
    }).then(r => r.json())

    if (res.status === "playing") {
      this.browseTarget.classList.add("hidden")
      this.remoteOutlet.show(title)
    }

    card.classList.remove("playing")
  }

  async powerOff() {
    if (!confirm("Are you sure you want to shut down?")) return
    await fetch("/system/power_off", {
      method: "POST",
      headers: { "Content-Type": "application/json" }
    })
    document.body.innerHTML = '<div style="display:flex;align-items:center;justify-content:center;height:100vh;color:#888;font-size:1.2rem">Shutting down...</div>'
  }

  showBrowse() {
    this.browseTarget.classList.remove("hidden")
  }

  updatePagination() {
    this.pageInfoTarget.textContent = `Page ${this.page} of ${this.totalPages}`
    this.prevBtnTarget.disabled = this.page <= 1
    this.nextBtnTarget.disabled = this.page >= this.totalPages
  }

  escapeAttr(str) {
    return str.replace(/"/g, "&quot;").replace(/'/g, "&#39;")
  }
}
