# frozen_string_literal: true

module Game
  class Faction < ApplicationRecord
    self.table_name = 'game_factions'

    belongs_to :game_system, class_name: 'Game::System'

    has_many :game_participations, class_name: 'Game::Participation', dependent: :restrict_with_exception

    validates :name, presence: true, length: { maximum: 100 }
    validates :name, uniqueness: { scope: :game_system_id }
  end
end
