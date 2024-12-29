# frozen_string_literal: true

module Game
  class System < ApplicationRecord
    has_many :events, class_name: 'Game::Event', dependent: :destroy
    has_many :participations, through: :events
    has_many :players, through: :participations, source: :user

    validates :name, presence: true, uniqueness: true
    validates :description, presence: true
  end
end
