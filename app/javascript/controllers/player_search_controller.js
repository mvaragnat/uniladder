import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "selected"]

  connect() {
    this.selectedPlayers = new Set()
  }

  search() {
    const query = this.inputTarget.value
    if (query.length < 2) return

    fetch(`/users/search?q=${encodeURIComponent(query)}`)
      .then(response => response.json())
      .then(data => this.showResults(data))
  }

  showResults(users) {
    this.resultsTarget.innerHTML = users
      .filter(user => !this.selectedPlayers.has(String(user.id)))
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

    this.element.dispatchEvent(new CustomEvent('player-selected', { bubbles: true, detail: { userId, username } }))
  }

  removePlayer(event) {
    const { userId } = event.currentTarget.dataset
    this.selectedPlayers.delete(String(userId))
    event.currentTarget.closest('.selected-player').remove()

    this.element.dispatchEvent(new CustomEvent('player-removed', { bubbles: true, detail: { userId } }))
  }

  userTemplate(user) {
    return `
      <div class="p-2 hover:bg-gray-100 cursor-pointer"
           data-action="click->player-search#selectPlayer"
           data-player-search-user-id="${user.id}"
           data-player-search-username="${user.username}">
        ${user.username}
      </div>
    `
  }

  selectedPlayerTemplate(userId, username) {
    return `
      <div class="selected-player flex items-center justify-between bg-gray-100 p-2 rounded" data-user-id="${userId}">
        <span>${username}</span>
        <button type="button"
                data-action="click->player-search#removePlayer"
                data-user-id="${userId}"
                class="text-red-600 hover:text-red-800">
          ×
        </button>
      </div>
    `
  }
} 