# frozen_string_literal: true

class EloController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @systems = load_systems
    @system = selected_system(@systems)
    @events = load_events(@system)
    @elo_changes_map = load_elo_changes(@events)
    @standings = compute_standings(@system)
  end

  private

  def load_systems
    Game::System.all.sort_by(&:localized_name)
  end

  def selected_system(systems)
    return systems.first if params[:game_system_id].blank?

    Game::System.find(params[:game_system_id])
  end

  def load_events(system)
    return Game::Event.none unless system

    Game::Event.where(game_system: system)
               .includes(:game_system, :game_participations, :players)
               .order(played_at: :desc)
  end

  def load_elo_changes(events)
    return {} if events.blank?

    changes = EloChange.where(game_event_id: events.map(&:id))
    changes.index_by { |ec| [ec.game_event_id, ec.user_id] }
  end

  def compute_standings(system)
    return [] unless system

    scope = ratings_scope(system)
    combined = combine_top_and_around(scope)
    with_ranks(scope, combined)
  end

  def ratings_scope(system)
    EloRating.where(game_system: system).includes(:user).order(rating: :desc)
  end

  def combine_top_and_around(scope)
    top = scope.limit(10).to_a
    around = around_current_user(scope)
    (top + around).uniq(&:user_id)
  end

  def around_current_user(scope)
    return [] unless Current.user

    user_row = scope.find_by(user: Current.user)
    return [] unless user_row

    pos = scope.where('rating > ?', user_row.rating).count
    offset = [pos - 3, 0].max
    scope.offset(offset).limit(7).to_a
  end

  def with_ranks(scope, rows)
    rows
      .map { |row| { rank: scope.where('rating > ?', row.rating).count + 1, row: row } }
      .sort_by { |h| h[:rank] }
  end
end
