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

      a_score = params.dig(:tournament_match, :a_score)
      b_score = params.dig(:tournament_match, :b_score)

      if a_score.present? && b_score.present?
        event = Game::Event.new(
          game_system: @tournament.game_system,
          played_at: Time.current
        )
        event.game_participations.build(user: @match.a_user, score: a_score)
        event.game_participations.build(user: @match.b_user, score: b_score)

        if event.save
          @match.game_event = event
          @match.result = deduce_result(a_score.to_i, b_score.to_i)
          @match.save!
          redirect_to tournament_tournament_match_path(@tournament, @match),
                      notice: t('tournaments.match_updated', default: 'Match updated')
          return
        else
          flash.now[:alert] = event.errors.full_messages.to_sentence
          render :show, status: :unprocessable_entity
          return
        end
      end

      # Fallback: allow direct result updates (legacy)
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

    def deduce_result(a_score, b_score)
      return 'draw' if a_score == b_score

      a_score > b_score ? 'a_win' : 'b_win'
    end
  end
end
