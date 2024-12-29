# frozen_string_literal: true

class User < ApplicationRecord
  has_many :game_participations, class_name: 'Game::Participation', dependent: :destroy
  has_many :game_events, through: :game_participations, class_name: 'Game::Event'
  has_many :game_systems, through: :game_events, class_name: 'Game::System'

  validates :username, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
