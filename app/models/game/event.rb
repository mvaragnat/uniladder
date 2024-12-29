# frozen_string_literal: true

module Game
  class Event < ApplicationRecord
    belongs_to :game_system, class_name: 'Game::System'
    has_many :participations, 
             class_name: 'Game::Participation',
             foreign_key: 'game_event_id',
             dependent: :destroy
    has_many :players, through: :participations, source: :user

    validates :played_at, presence: true
    # validate :must_have_at_least_two_players

    private

    # def must_have_at_least_two_players
    #   errors.add(:players, 'must have at least two players') if players.size < 2
    # end
  end
end
