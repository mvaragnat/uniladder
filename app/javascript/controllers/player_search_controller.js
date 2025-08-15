import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "selected", "container"]

  connect() {
    this.selectedPlayers = new Set()
  }

  search() {
    const query = this.inputTarget.value
    if (query.length < 1) {
      this.resultsTarget.innerHTML = ''
      return
    }

    const tId = this.inputTarget.dataset.tournamentId
    const url = tId ? `/users/search?q=${encodeURIComponent(query)}&tournament_id=${encodeURIComponent(tId)}`
                    : `/users/search?q=${encodeURIComponent(query)}`

    fetch(url)
      .then(response => response.json())
      .then(data => this.showResults(data))
  }

  showResults(users) {
    const filtered = users
      .filter(user => !this.selectedPlayers.has(String(user.id)))
      .slice(0, 10)

    if (filtered.length === 0) {
      this.resultsTarget.innerHTML = `<div style="padding:0.75rem;color:#6b7280;">No results found</div>`
      return
    }

    this.resultsTarget.innerHTML = filtered
      .map(user => this.userTemplate(user))
      .join('')
  }

  selectPlayer(event) {
    const userId = event.currentTarget.dataset.playerSearchUserId
    const username = event.currentTarget.dataset.playerSearchUsername
    if (this.selectedPlayers.has(String(userId))) return

    // Allow only one opponent selection
    if (this.selectedPlayers.size >= 1) return

    this.selectedPlayers.add(String(userId))
    this.selectedTarget.insertAdjacentHTML('beforeend', this.selectedPlayerTemplate(userId, username))
    this.resultsTarget.innerHTML = ''
    this.inputTarget.value = ''

    // Hide selector when chosen
    if (this.hasContainerTarget) this.containerTarget.style.display = 'none'

    this.element.dispatchEvent(new CustomEvent('player-selected', { bubbles: true, detail: { userId, username } }))
  }

  removePlayer(event) {
    const { userId } = event.currentTarget.dataset
    this.selectedPlayers.delete(String(userId))
    event.currentTarget.closest('.selected-player').remove()

    // Show selector again
    if (this.hasContainerTarget) this.containerTarget.style.display = ''

    this.element.dispatchEvent(new CustomEvent('player-removed', { bubbles: true, detail: { userId } }))
  }

  userTemplate(user) {
    return `
      <div data-action="click->player-search#selectPlayer"
           data-player-search-user-id="${user.id}"
           data-player-search-username="${user.username}">
        <strong>${user.username}</strong>
      </div>
    `
  }

  selectedPlayerTemplate(userId, username) {
    return `
      <div class="selected-player" data-user-id="${userId}">
        <span><strong>${username}</strong> (opponent)</span>
        <button type="button"
                data-action="click->player-search#removePlayer"
                data-user-id="${userId}">
          ×
        </button>
      </div>
    `
  }
} 