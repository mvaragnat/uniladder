# frozen_string_literal: true

module Tournament
  class RegistrationsController < ApplicationController
    before_action :authenticate!
    before_action :set_tournament

    def update
      registration = @tournament.registrations.find(params[:id])
      unless can_update?(registration)
        return redirect_back(fallback_location: tournament_path(@tournament),
                             alert: t('tournaments.unauthorized', default: 'Not authorized'))
      end

      if registration.update(registration_params)
        redirect_to tournament_path(@tournament, tab: 1),
                    notice: t('tournaments.registration_updated', default: 'Registration updated')
      else
        redirect_to tournament_path(@tournament, tab: 1),
                    alert: registration.errors.full_messages.to_sentence
      end
    end

    private

    def authenticate!
      redirect_to new_session_path unless Current.user
    end

    def set_tournament
      @tournament = ::Tournament::Tournament.find(params[:tournament_id])
    end

    def can_update?(registration)
      return true if @tournament.creator_id == Current.user.id

      registration.user_id == Current.user.id
    end

    def registration_params
      params.expect(tournament_registration: [:faction_id])
    end
  end
end
