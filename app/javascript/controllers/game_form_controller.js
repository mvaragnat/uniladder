import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["error", "scores"]

  validate(event) {
    const form = this.element
    const selectedContainer = form.querySelector('[data-player-search-target="selected"]')
    const selected = selectedContainer ? selectedContainer.querySelectorAll('.selected-player') : []

    // We always have current user as one participant; require exactly one opponent selected
    if (!selected || selected.length !== 1) {
      event.preventDefault()
      this.showError(window.I18n?.t('games.errors.exactly_two_players') || 'Select exactly one opponent')
      return
    }

    // Verify both scores are present
    const myScoreInput = form.querySelector('input[name="game_event[game_participations_attributes][0][score]"]')
    const myScore = myScoreInput?.value?.trim()
    const selectedNode = selected[0]
    const opponentScoreName = 'game_event[game_participations_attributes][1][score]'

    // Ensure opponent user_id hidden
    form.querySelectorAll('input[name="game_event[game_participations_attributes][1][user_id]"]').forEach(n => n.remove())
    const userId = selectedNode.getAttribute('data-user-id')
    const hiddenUser = document.createElement('input')
    hiddenUser.type = 'hidden'
    hiddenUser.name = 'game_event[game_participations_attributes][1][user_id]'
    hiddenUser.value = userId
    form.appendChild(hiddenUser)

    // Ensure opponent score exists
    let opponentScoreInput = form.querySelector(`input[name="${opponentScoreName}"]`)
    if (!opponentScoreInput) {
      opponentScoreInput = document.createElement('input')
      opponentScoreInput.type = 'hidden'
      opponentScoreInput.name = opponentScoreName
      form.appendChild(opponentScoreInput)
    }

    const opponentScore = opponentScoreInput.value?.trim()

    if (!myScore || !opponentScore) {
      event.preventDefault()
      this.showError(window.I18n?.t('games.errors.both_scores_required') || 'Both scores are required')
      return
    }

    // Require factions for both
    const myFaction = form.querySelector('select[name="game_event[game_participations_attributes][0][faction_id]"]')?.value
    const oppFaction = form.querySelector('select[name="game_event[game_participations_attributes][1][faction_id]"]')?.value
    if (!myFaction || !oppFaction) {
      event.preventDefault()
      this.showError(window.I18n?.t('games.errors.both_factions_required') || 'Both players must select a faction')
      return
    }

    this.hideError()
  }

  showScores() {
    if (this.hasScoresTarget) {
      this.scoresTarget.classList.remove('hidden')
    }
  }

  toggleScores() {
    const selectedContainer = this.element.querySelector('[data-player-search-target="selected"]')
    const hasOpponent = selectedContainer && selectedContainer.querySelectorAll('.selected-player').length === 1
    if (this.hasScoresTarget) {
      this.scoresTarget.classList.toggle('hidden', !hasOpponent)
    }
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove('hidden')
  }

  hideError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ''
    this.errorTarget.classList.add('hidden')
  }
} 