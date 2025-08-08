# frozen_string_literal: true

module Game
  class Participation < ApplicationRecord
    belongs_to :game_event, class_name: 'Game::Event'
    belongs_to :user

    validates :score, presence: true
    validates :user_id, uniqueness: { scope: :game_event_id }
  end
end
