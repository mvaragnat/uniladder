# frozen_string_literal: true

module Tournament
  class MatchesController < ApplicationController
    before_action :authenticate!
    before_action :set_tournament
    before_action :set_match, only: %i[show update]
    before_action :authorize_update!, only: %i[update]

    def index
      @matches = @tournament.matches.order(created_at: :desc)
    end

    def show; end

    def update
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

    def set_match
      @match = @tournament.matches.find(params[:id])
    end

    def match_params
      params.require(:tournament_match).permit(:result)
    end

    def deduce_result(a_score, b_score)
      return 'draw' if a_score == b_score

      a_score > b_score ? 'a_win' : 'b_win'
    end

    def authorize_update!
      # If already reported, only organizer/admin may change
      if @match.game_event.present? && @tournament.creator != Current.user
        redirect_to tournament_tournament_match_path(@tournament, @match),
                    alert: t('tournaments.unauthorized', default: 'Not authorized') and return
      end

      # For first report, only participants or organizer
      return if [@match.a_user_id, @match.b_user_id].include?(Current.user.id)
      return if @tournament.creator == Current.user

      redirect_to tournament_tournament_match_path(@tournament, @match),
                  alert: t('tournaments.unauthorized', default: 'Not authorized')
    end
  end
end
