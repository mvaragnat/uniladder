# frozen_string_literal: true

module Tournament
  class Tournament < ApplicationRecord
    self.table_name = 'tournaments'

    enum :format, { open: 0, swiss: 1, elimination: 2 }
    enum :state, { draft: 'draft', registration: 'registration', running: 'running', completed: 'completed' }

    belongs_to :creator, class_name: 'User'
    belongs_to :game_system, class_name: 'Game::System'

    has_many :registrations,
             class_name: 'Tournament::Registration',
             inverse_of: :tournament,
             dependent: :destroy
    has_many :participants, through: :registrations, source: :user

    has_many :rounds,
             class_name: 'Tournament::Round',
             inverse_of: :tournament,
             dependent: :destroy

    has_many :matches,
             class_name: 'Tournament::Match',
             inverse_of: :tournament,
             dependent: :destroy

    validates :name, presence: true
    validates :format, presence: true
    validates :rounds_count, numericality: { greater_than: 0 }, allow_nil: true

    def registrations_open?
      state.in?(%w[draft registration])
    end

    def state_label
      I18n.t("tournaments.state.#{state}", default: state.to_s.humanize)
    end
  end
end
