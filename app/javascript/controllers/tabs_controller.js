import { Controller } from "@hotwired/stimulus"

// data-controller="tabs"
// data-tabs-target="tab" for buttons and data-tabs-target="panel" for panels
// Optional: data-tabs-active-index-value to set initial active tab (default 0)
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { activeIndex: { type: Number, default: 0 } }

  connect() {
    this.show(this.activeIndexValue)
  }

  select(event) {
    event.preventDefault()
    const index = Number(event.currentTarget.dataset.index)
    this.show(index)
  }

  show(index) {
    this.activeIndexValue = index

    this.tabTargets.forEach((el, i) => {
      const selected = i === index
      el.setAttribute("aria-selected", selected ? "true" : "false")
      el.classList.toggle("btn-primary", selected)
    })

    this.panelTargets.forEach((el, i) => {
      el.style.display = i === index ? "block" : "none"
    })
  }
} 