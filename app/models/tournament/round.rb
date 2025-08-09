# frozen_string_literal: true

module Tournament
  class Round < ApplicationRecord
    self.table_name = 'tournament_rounds'

    belongs_to :tournament, class_name: 'Tournament::Tournament'
    has_many :matches, class_name: 'Tournament::Match', dependent: :destroy, foreign_key: 'tournament_round_id',
                       inverse_of: :round

    validates :number, presence: true
  end
end
