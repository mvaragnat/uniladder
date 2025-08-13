# frozen_string_literal: true

class TournamentsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  before_action :authenticate!, except: %i[index show]
  before_action :set_tournament,
                only: %i[show register unregister check_in lock_registration finalize next_round update]
  before_action :authorize_admin!, only: %i[lock_registration finalize next_round update]

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

    # Expose strategies for Admin dropdowns
    @pairing_strategies = Tournament::StrategyRegistry.pairing_strategies
    @tiebreak_strategies = Tournament::StrategyRegistry.tiebreak_strategies

    standings_data = compute_standings_with_tiebreaks(@tournament)
    @standings = standings_data[:rows]
    @tiebreak1_label = standings_data[:tiebreak1_label]
    @tiebreak2_label = standings_data[:tiebreak2_label]

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

    # Generate pairings via registry strategy
    pairing_cls = Tournament::StrategyRegistry.pairing_strategies[@tournament.pairing_key].last
    pairs = pairing_cls.new(@tournament).call.pairs
    pairs.each do |a_user, b_user|
      @tournament.matches.create!(round: new_round, a_user: a_user, b_user: b_user)
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

  def update
    admin_tab_index = @tournament.elimination? ? 2 : 3
    if @tournament.update(tournament_params)
      respond_to do |format|
        format.html do
          redirect_to tournament_path(@tournament, tab: admin_tab_index),
                      notice: t('tournaments.updated', default: 'Tournament updated')
        end
        format.json { render json: { ok: true, message: t('tournaments.updated', default: 'Tournament updated') } }
      end
    else
      respond_to do |format|
        format.html do
          redirect_to tournament_path(@tournament, tab: admin_tab_index),
                      alert: @tournament.errors.full_messages.join(', ')
        end
        format.json do
          render json: { ok: false, errors: @tournament.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
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
                                       :ends_at,
                                       :pairing_strategy_key, :tiebreak1_strategy_key, :tiebreak2_strategy_key)
  end

  def can_register?
    @tournament.state.in?(%w[draft registration])
  end

  # Returns rows with points and tiebreak columns and labels
  def compute_standings_with_tiebreaks(tournament)
    points = Hash.new(0.0)
    score_sum = Hash.new(0.0)

    users = tournament.registrations.includes(:user).map(&:user)
    users.each do |u|
      points[u.id] ||= 0.0
      score_sum[u.id] ||= 0.0
    end

    aggregate_points_and_scores(tournament, points, score_sum)

    agg = { score_sum_by_user_id: score_sum }

    t1 = Tournament::StrategyRegistry.tiebreak_strategies[tournament.tiebreak1_key]
    t2 = Tournament::StrategyRegistry.tiebreak_strategies[tournament.tiebreak2_key]

    rows = users.map do |u|
      {
        user: u,
        points: points[u.id],
        tiebreak1: t1.last.call(u.id, agg),
        tiebreak2: t2.last.call(u.id, agg)
      }
    end

    rows.sort_by! { |h| [-h[:points], -h[:tiebreak1], -h[:tiebreak2], h[:user].username] }

    { rows: rows, tiebreak1_label: t1.first, tiebreak2_label: t2.first }
  end

  def aggregate_points_and_scores(tournament, points, score_sum)
    tournament.matches.includes(:a_user, :b_user, :game_event).find_each do |m|
      next unless m.a_user && m.b_user

      a_score = nil
      b_score = nil
      if m.game_event
        a_part = m.game_event.game_participations.find_by(user: m.a_user)
        b_part = m.game_event.game_participations.find_by(user: m.b_user)
        a_score = a_part&.score.to_f
        b_score = b_part&.score.to_f
      end

      case m.result
      when 'a_win'
        points[m.a_user.id] += 1.0
      when 'b_win'
        points[m.b_user.id] += 1.0
      when 'draw'
        points[m.a_user.id] += 0.5
        points[m.b_user.id] += 0.5
      end

      next unless a_score && b_score

      score_sum[m.a_user.id] += a_score
      score_sum[m.b_user.id] += b_score
    end
  end
end
