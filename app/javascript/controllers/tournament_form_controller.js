import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tournament-form"
export default class extends Controller {
  static targets = ["format", "rounds"]

  connect() {
    this.toggleRounds()
  }

  toggleRounds() {
    const value = this.formatTarget.value
    const show = value === "swiss"
    this.roundsTarget.style.display = show ? "block" : "none"
  }
} 