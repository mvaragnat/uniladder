# frozen_string_literal: true

class EloChange < ApplicationRecord
  belongs_to :game_event, class_name: 'Game::Event'
  belongs_to :user
  belongs_to :game_system, class_name: 'Game::System'

  validates :rating_before, :rating_after, :expected_score, :actual_score, :k_factor, presence: true
end
