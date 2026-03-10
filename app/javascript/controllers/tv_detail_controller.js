import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "title", "seasonSelect", "episodeList"]
  static outlets = ["remote", "search"]

  connect() {
    this.currentTvId = null
    this.currentSeason = null
    this.currentName = null
  }

  async open(event) {
    const card = event.currentTarget
    this.currentTvId = card.dataset.tvId
    this.currentName = card.dataset.tvName

    this.titleTarget.textContent = this.currentName
    this.episodeListTarget.innerHTML = ""
    this.seasonSelectTarget.innerHTML = '<option value="">Loading...</option>'
    this.modalTarget.classList.add("visible")

    const data = await this.fetchJSON(`/tmdb/tv/${this.currentTvId}`)
    const seasons = (data.seasons || []).filter(s => s.season_number > 0)

    if (seasons.length === 0) {
      this.seasonSelectTarget.innerHTML = '<option value="">No seasons found</option>'
      return
    }

    this.seasonSelectTarget.innerHTML = seasons.map(s =>
      `<option value="${s.season_number}">Season ${s.season_number} (${s.episode_count} episodes)</option>`
    ).join("")

    this.loadSeason()
  }

  async loadSeason() {
    const seasonNum = this.seasonSelectTarget.value
    if (!seasonNum) return

    this.currentSeason = seasonNum
    this.episodeListTarget.innerHTML = '<p class="loading">Loading episodes...</p>'

    const data = await this.fetchJSON(`/tmdb/tv/${this.currentTvId}/season/${seasonNum}`)
    const episodes = data.episodes || []

    if (episodes.length === 0) {
      this.episodeListTarget.innerHTML = '<p class="no-results">No episodes found.</p>'
      return
    }

    this.episodeListTarget.innerHTML = episodes.map(ep => {
      const still = ep.still_path
        ? `<img src="https://image.tmdb.org/t/p/w300${ep.still_path}" alt="Episode ${ep.episode_number}" loading="lazy">`
        : ""
      const rating = ep.vote_average ? ep.vote_average.toFixed(1) : ""
      const epTitle = ep.name || ("Episode " + ep.episode_number)
      return `
        <div class="episode-card" data-action="click->tv-detail#playEpisode"
             data-episode="${ep.episode_number}" data-ep-title="${epTitle.replace(/"/g, '&quot;')}">
          <div class="episode-still">${still}</div>
          <div class="episode-info">
            <strong>E${ep.episode_number}: ${epTitle}</strong>
            ${rating ? `<span class="rating">&#9733; ${rating}</span>` : ""}
            ${ep.overview ? `<p>${ep.overview}</p>` : ""}
          </div>
        </div>`
    }).join("")
  }

  async playEpisode(event) {
    const card = event.currentTarget
    const episode = card.dataset.episode
    const epTitle = card.dataset.epTitle
    card.classList.add("playing")

    const displayTitle = `${this.currentName} — S${this.currentSeason}E${episode}: ${epTitle}`

    const res = await fetch("/player/play", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        tmdb_id: this.currentTvId,
        media_type: "tv",
        season: this.currentSeason,
        episode: episode,
        title: displayTitle
      })
    }).then(r => r.json())

    if (res.status === "playing") {
      this.close()
      this.searchOutlet.browseTarget.classList.add("hidden")
      this.remoteOutlet.show(displayTitle)
    }

    card.classList.remove("playing")
  }

  close() {
    this.modalTarget.classList.remove("visible")
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  async fetchJSON(url) {
    const resp = await fetch(url)
    return resp.json()
  }
}
