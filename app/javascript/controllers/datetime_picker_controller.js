import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

export default class extends Controller {
  static values = {
    enableTime: { type: Boolean, default: true },
    dateFormat: { type: String, default: "Y-m-d H:i" }
  }

  connect() {
    this.picker = flatpickr(this.element, {
      enableTime: this.enableTimeValue,
      dateFormat: this.dateFormatValue
    })
  }

  disconnect() {
    if (this.picker) this.picker.destroy()
  }
} 