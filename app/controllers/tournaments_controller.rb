# frozen_string_literal: true

class TournamentsController < ApplicationController
  before_action :authenticate!
  before_action :set_tournament,
                only: %i[show register unregister check_in lock_registration generate_pairings close_round finalize]

  def index
    @tournaments = ::Tournament::Tournament.order(created_at: :desc).includes(:game_system, :creator)
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
    reg = @tournament.registrations.find_by!(user: Current.user)
    reg.update!(status: 'checked_in')
    redirect_to tournament_path(@tournament), notice: t('tournaments.checked_in', default: 'Checked in')
  end

  # Admin placeholders
  def lock_registration
    @tournament.update!(state: 'running')
    redirect_to tournament_path(@tournament), notice: t('tournaments.locked', default: 'Registration locked')
  end

  def generate_pairings
    unless @tournament.open?
      round = @tournament.rounds.order(:number).last || @tournament.rounds.create!(number: 1, state: 'pending')
      players = @tournament.registrations.where(status: 'checked_in').includes(:user).map(&:user)
      players = @tournament.registrations.includes(:user).map(&:user) if players.size < 2
      players = players.sort_by(&:id)

      # Avoid duplicating matches for an existing round
      if round.matches.count.zero?
        players.each_slice(2) do |a, b|
          break unless b

          @tournament.matches.create!(round: round, a_user: a, b_user: b)
        end
      end
    end

    redirect_to tournament_path(@tournament), notice: t('tournaments.pairings_generated', default: 'Pairings generated')
  end

  def close_round
    if (round = @tournament.rounds.order(:number).last)
      round.update!(state: 'closed')
    end
    redirect_to tournament_path(@tournament), notice: t('tournaments.round_closed', default: 'Round closed')
  end

  def finalize
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

  def tournament_params
    params.require(:tournament).permit(:name, :description, :game_system_id, :format, :rounds_count, :starts_at,
                                       :ends_at)
  end

  def can_register?
    @tournament.state.in?(%w[draft registration])
  end
end
