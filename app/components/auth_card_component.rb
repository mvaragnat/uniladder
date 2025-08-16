# frozen_string_literal: true

class AuthCardComponent < ViewComponent::Base
  def initialize(title:, subtitle: nil)
    super()
    @title = title
    @subtitle = subtitle
  end
end
