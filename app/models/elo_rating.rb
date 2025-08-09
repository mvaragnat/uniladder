# frozen_string_literal: true

class EloRating < ApplicationRecord
  START_RATING = 1200

  belongs_to :user
  belongs_to :game_system, class_name: 'Game::System'

  validates :rating, presence: true
  validates :games_played, presence: true
end
