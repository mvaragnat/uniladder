# frozen_string_literal: true

class TournamentsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  before_action :authenticate!, except: %i[index show]
  before_action :set_tournament,
                only: %i[show register unregister check_in lock_registration generate_pairings close_round finalize]
  before_action :authorize_admin!, only: %i[lock_registration generate_pairings close_round finalize]

  def index
    scope = ::Tournament::Tournament.includes(:game_system, :creator).order(created_at: :desc)
    @my_tournaments = Current.user ? scope.where(creator: Current.user) : scope.none
    @accepting_tournaments = scope.where(state: %w[draft registration])
    @ongoing_tournaments = scope.where(state: 'running')
    @closed_tournaments = scope.where(state: 'completed')
  end

  def show
    @registrations = @tournament.registrations.includes(:user)
    @rounds = @tournament.rounds.order(:number)
    @matches = @tournament.matches.order(created_at: :desc).limit(20)
  end

  def new
    @tournament = ::Tournament::Tournament.new
  end

  def create
    @tournament = ::Tournament::Tournament.new(tournament_params)
    @tournament.creator = Current.user

    if @tournament.save
      redirect_to tournament_path(@tournament), notice: t('tournaments.created', default: 'Tournament created')
    else
      render :new, status: :unprocessable_entity
    end
  end

  def register
    unless can_register?
      return redirect_back(
        fallback_location: tournament_path(@tournament),
        alert: t('tournaments.closed', default: 'Registration closed')
      )
    end

    @tournament.registrations.find_or_create_by!(user: Current.user)
    redirect_to tournament_path(@tournament), notice: t('tournaments.registered', default: 'Registered')
  end

  def unregister
    unless can_register?
      return redirect_back(
        fallback_location: tournament_path(@tournament),
        alert: t('tournaments.closed', default: 'Registration closed')
      )
    end

    @tournament.registrations.where(user: Current.user).destroy_all
    redirect_to tournament_path(@tournament), notice: t('tournaments.unregistered', default: 'Unregistered')
  end

  def check_in
    unless can_register?
      return redirect_back(
        fallback_location: tournament_path(@tournament),
        alert: t('tournaments.closed', default: 'Registration closed')
      )
    end

    reg = @tournament.registrations.find_by!(user: Current.user)
    reg.update!(status: 'checked_in')
    redirect_to tournament_path(@tournament), notice: t('tournaments.checked_in', default: 'Checked in')
  end

  # Admin
  def lock_registration
    unless can_register?
      return redirect_back(
        fallback_location: tournament_path(@tournament),
        alert: t('tournaments.not_allowed_state', default: 'Not allowed in current state')
      )
    end

    ApplicationRecord.transaction do
      @tournament.update!(state: 'running')
      @tournament.reload
      Tournament::BracketBuilder.new(@tournament).call if @tournament.elimination?
    end

    redirect_to tournament_path(@tournament), notice: t('tournaments.locked', default: 'Registration locked')
  end

  def generate_pairings
    if @tournament.elimination?
      return redirect_back(
        fallback_location: tournament_path(@tournament),
        alert: t('tournaments.not_allowed_state', default: 'Not allowed in current state')
      )
    end

    unless @tournament.running?
      return redirect_back(
        fallback_location: tournament_path(@tournament),
        alert: t('tournaments.not_allowed_state', default: 'Not allowed in current state')
      )
    end

    # Swiss pairing placeholder (not implemented yet)
    round = @tournament.rounds.order(:number).last || @tournament.rounds.create!(number: 1, state: 'pending')
    players = @tournament.registrations.where(status: 'checked_in').includes(:user).map(&:user)
    players = players.presence || @tournament.registrations.includes(:user).map(&:user)
    players = players.sort_by(&:id)

    if round.matches.none?
      players.each_slice(2) do |a, b|
        break unless b

        @tournament.matches.create!(round: round, a_user: a, b_user: b)
      end
    end

    redirect_to tournament_path(@tournament), notice: t('tournaments.pairings_generated', default: 'Pairings generated')
  end

  def close_round
    if @tournament.elimination?
      return redirect_back(
        fallback_location: tournament_path(@tournament),
        alert: t('tournaments.not_allowed_state', default: 'Not allowed in current state')
      )
    end

    unless @tournament.running?
      return redirect_back(
        fallback_location: tournament_path(@tournament),
        alert: t('tournaments.not_allowed_state', default: 'Not allowed in current state')
      )
    end

    if (round = @tournament.rounds.order(:number).last)
      round.update!(state: 'closed')
    end
    redirect_to tournament_path(@tournament), notice: t('tournaments.round_closed', default: 'Round closed')
  end

  def finalize
    unless @tournament.running?
      return redirect_back(
        fallback_location: tournament_path(@tournament),
        alert: t('tournaments.not_allowed_state', default: 'Not allowed in current state')
      )
    end

    @tournament.update!(state: 'completed')
    redirect_to tournament_path(@tournament), notice: t('tournaments.finalized', default: 'Tournament finalized')
  end

  private

  def authenticate!
    redirect_to new_session_path unless Current.user
  end

  def set_tournament
    @tournament = ::Tournament::Tournament.find(params[:id])
  end

  def authorize_admin!
    return if Current.user && @tournament.creator_id == Current.user.id

    redirect_back(
      fallback_location: tournament_path(@tournament),
      alert: t('tournaments.unauthorized', default: 'Not authorized')
    )
  end

  def tournament_params
    params.require(:tournament).permit(:name, :description, :game_system_id, :format, :rounds_count, :starts_at,
                                       :ends_at)
  end

  def can_register?
    @tournament.state.in?(%w[draft registration])
  end
end
