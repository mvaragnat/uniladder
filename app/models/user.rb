# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :game_participations, class_name: 'Game::Participation', dependent: :destroy
  has_many :game_events, through: :game_participations, class_name: 'Game::Event'
  has_many :game_systems, through: :game_events, class_name: 'Game::System'
  # Legacy custom authentication removed in favor of Devise

  validates :username, presence: true, uniqueness: true
  # Devise expects `email`
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
