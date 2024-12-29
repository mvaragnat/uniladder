# frozen_string_literal: true

class User < ApplicationRecord
  has_many :game_participations, class_name: 'Game::Participation', dependent: :destroy
  has_many :game_events, through: :game_participations, class_name: 'Game::Event'
  has_many :game_systems, through: :game_events, class_name: 'Game::System'
  has_secure_password
  has_many :sessions, dependent: :destroy

  validates :username, presence: true, uniqueness: true
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
