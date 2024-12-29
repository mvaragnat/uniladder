# frozen_string_literal: true

module Game
  class Participation < ApplicationRecord
    belongs_to :event
    belongs_to :user

    validates :result, presence: true
    validates :user_id, uniqueness: { scope: :event_id }
  end
end
