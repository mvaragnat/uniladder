# frozen_string_literal: true

class DashboardsController < ApplicationController
  before_action :authenticate!

  def show
    @user = Current.user
    @games = @user.game_events.includes(:game_system, :game_participations, :players)
                  .order(played_at: :desc)
    @elo_ratings = EloRating.where(user: @user).includes(:game_system).order('game_systems.name')
  end

  private

  def authenticate!
    redirect_to new_session_path unless Current.user
  end
end
