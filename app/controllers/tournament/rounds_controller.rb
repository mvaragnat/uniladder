# frozen_string_literal: true

module Tournament
  class RoundsController < ApplicationController
    before_action :authenticate!
    before_action :set_tournament

    def index
      @rounds = @tournament.rounds.order(:number)
    end

    def show
      @round = @tournament.rounds.find(params[:id])
      @matches = @round.matches.includes(:a_user, :b_user)
    end

    private

    def authenticate!
      redirect_to new_session_path unless Current.user
    end

    def set_tournament
      @tournament = ::Tournament::Tournament.find(params[:tournament_id])
    end
  end
end
