# frozen_string_literal: true

module Tournament
  class MatchesController < ApplicationController
    before_action :authenticate!
    before_action :set_tournament

    def index
      @matches = @tournament.matches.order(created_at: :desc)
    end

    def show
      @match = @tournament.matches.find(params[:id])
    end

    def update
      @match = @tournament.matches.find(params[:id])
      if @match.update(match_params)
        redirect_to tournament_tournament_match_path(@tournament, @match),
                    notice: t('tournaments.match_updated', default: 'Match updated')
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def authenticate!
      redirect_to new_session_path unless Current.user
    end

    def set_tournament
      @tournament = ::Tournament::Tournament.find(params[:tournament_id])
    end

    def match_params
      params.require(:tournament_match).permit(:result)
    end
  end
end
