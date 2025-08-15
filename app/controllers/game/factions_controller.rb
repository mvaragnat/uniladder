# frozen_string_literal: true

module Game
  class FactionsController < ApplicationController
    def index
      system_id = params[:game_system_id]
      factions = if system_id.present?
                   Game::Faction.where(game_system_id: system_id).order(:name)
                 else
                   Game::Faction.none
                 end
      render json: factions.map { |f| { id: f.id, name: f.name } }
    end
  end
end
