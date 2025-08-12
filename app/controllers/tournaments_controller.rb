# frozen_string_literal: true

class TournamentsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  before_action :authenticate!, except: %i[index show]
  before_action :set_tournament,
                only: %i[show register unregister check_in lock_registration finalize next_round]
  before_action :authorize_admin!, only: %i[lock_registration finalize next_round]

  def index
    # Populate Current.session/user even when authentication is not required
    authenticated?

    scope = ::Tournament::Tournament.includes(:game_system, :creator).order(created_at: :desc)
    @my_tournaments = Current.user ? scope.where(creator: Current.user) : scope.none
    @accepting_tournaments = scope.where(state: %w[draft registration])
    @ongoing_tournaments = scope.where(state: 'running')
    @closed_tournaments = scope.where(state: 'completed')
  end

  def show
    # Populate Current.session/user for guest-access pages
    authenticated?

    @rounds = @tournament.rounds.includes(matches: %i[a_user b_user]).order(:number)
    @registrations = @tournament.registrations.includes(:user)
    @matches = @tournament.matches.order(created_at: :desc).limit(20)
    @active_tab_index = (params[:tab].presence || 0).to_i
    @is_registered = Current.user && @tournament.registrations.exists?(user_id: Current.user.id)
    @my_registration = Current.user && @tournament.registrations.find_by(user_id: Current.user.id)

    @standings = compute_simple_standings(@tournament)

    last_round = @rounds.last
    if last_round
      any_pending = last_round.matches.any? { |m| m.result == 'pending' }
      @can_move_to_next_round = !any_pending
      @move_block_reason = if any_pending
                             t('tournaments.cannot_advance_pending',
                               default: 'All matches must be completed to move to the next round')
                           end
    else
      # No rounds yet; allow starting the first round if running
      @can_move_to_next_round = @tournament.running?
      @move_block_reason = nil
    end
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
    redirect_to tournament_path(@tournament, tab: 1), notice: t('tournaments.registered', default: 'Registered')
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

  def next_round
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

    last_round = @tournament.rounds.order(:number).last
    if last_round
      if last_round.matches.any? { |m| m.result == 'pending' }
        return redirect_back(
          fallback_location: tournament_path(@tournament),
          alert: t('tournaments.cannot_advance_pending',
                   default: 'All matches must be completed to move to the next round')
        )
      end
      last_round.update!(state: 'closed') unless last_round.state == 'closed'
    end

    # Create next round
    next_number = (last_round&.number || 0) + 1
    new_round = @tournament.rounds.create!(number: next_number, state: 'pending')

    # Pairings generation (simple placeholder)
    players = @tournament.registrations.where(status: 'checked_in').includes(:user).map(&:user)
    players = players.presence || @tournament.registrations.includes(:user).map(&:user)
    players = players.sort_by(&:id)

    players.each_slice(2) do |a, b|
      break unless b

      @tournament.matches.create!(round: new_round, a_user: a, b_user: b)
    end

    redirect_to tournament_path(@tournament, tab: 0),
                notice: t('tournaments.round_advanced', default: 'Moved to next round')
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

  def compute_simple_standings(tournament)
    points = Hash.new { |h, k| h[k] = 0.0 }
    played = Hash.new(0)

    users = tournament.registrations.includes(:user).map(&:user)
    users.each do |u|
      points[u.id] ||= 0.0
      played[u.id] ||= 0
    end

    tournament.matches.includes(:a_user, :b_user).find_each do |m|
      next if m.result == 'pending'
      next unless m.a_user && m.b_user

      played[m.a_user.id] += 1
      played[m.b_user.id] += 1

      case m.result
      when 'a_win'
        points[m.a_user.id] += 1.0
      when 'b_win'
        points[m.b_user.id] += 1.0
      when 'draw'
        points[m.a_user.id] += 0.5
        points[m.b_user.id] += 0.5
      end
    end

    users.map { |u| { user: u, points: points[u.id], played: played[u.id] } }
         .sort_by { |h| [-h[:points], h[:user].username] }
  end
end
