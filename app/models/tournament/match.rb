# frozen_string_literal: true

module Tournament
  class Match < ApplicationRecord
    self.table_name = 'tournament_matches'

    RESULTS = %w[pending a_win b_win draw].freeze

    belongs_to :tournament, class_name: 'Tournament::Tournament', inverse_of: :matches
    belongs_to :round, class_name: 'Tournament::Round', optional: true, foreign_key: 'tournament_round_id',
                       inverse_of: :matches
    belongs_to :a_user, class_name: 'User'
    belongs_to :b_user, class_name: 'User'
    belongs_to :game_event, class_name: 'Game::Event', optional: true

    validates :result, inclusion: { in: RESULTS }
  end
end
