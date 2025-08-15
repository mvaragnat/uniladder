# frozen_string_literal: true

require 'test_helper'

class TournamentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:player_one)
  end

  test 'guests can access tournaments index' do
    get tournaments_path(locale: I18n.locale)
    assert_response :success
  end

  test 'guests can access tournaments show' do
    t = ::Tournament::Tournament.create!(
      name: 'Public Cup', description: 'Open to all',
      game_system: game_systems(:chess), format: 'open', creator: @user
    )

    get tournament_path(t, locale: I18n.locale)
    assert_response :success
  end

  test 'creates tournament with valid params from form' do
    # Sign in
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    assert_response :redirect

    assert_difference('Tournament::Tournament.count', 1) do
      post tournaments_path(locale: I18n.locale), params: {
        tournament: {
          name: 'Weekend Open',
          description: 'Test tournament',
          game_system_id: game_systems(:chess).id,
          format: 'swiss',
          rounds_count: 5,
          starts_at: '2025-08-06 18:00',
          ends_at: '2025-08-07 12:00'
        }
      }
    end

    tournament = Tournament::Tournament.order(:created_at).last
    assert_redirected_to tournament_path(tournament, locale: I18n.locale)
    assert_equal @user, tournament.creator
    assert_equal 'swiss', tournament.format
    assert_equal 5, tournament.rounds_count
  end

  test 'creates non-swiss tournament and redirects to show' do
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    assert_response :redirect

    assert_difference('Tournament::Tournament.count', 1) do
      post tournaments_path(locale: I18n.locale), params: {
        tournament: {
          name: 'Elim Cup',
          description: 'KO bracket',
          game_system_id: game_systems(:chess).id,
          format: 'elimination',
          rounds_count: '',
          starts_at: '2025-08-10 10:00',
          ends_at: '2025-08-10 18:00'
        }
      }
    end

    tournament = Tournament::Tournament.order(:created_at).last
    assert_redirected_to tournament_path(tournament, locale: I18n.locale)
    assert_equal 'elimination', tournament.format
  end

  test 'check_in is blocked once registration is locked' do
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post tournaments_path(locale: I18n.locale),
         params: { tournament: { name: 'X', description: 'Y', game_system_id: game_systems(:chess).id,
                                 format: 'open' } }
    t = Tournament::Tournament.order(:created_at).last

    post register_tournament_path(t, locale: I18n.locale)
    f = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'White')
    t.registrations.find_by(user: @user).update!(faction: f)
    post lock_registration_tournament_path(t, locale: I18n.locale)

    post check_in_tournament_path(t, locale: I18n.locale)
    assert_redirected_to tournament_path(t, locale: I18n.locale)
  end

  test 'cannot check-in without faction set' do
    # Sign in and create tournament
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post tournaments_path(locale: I18n.locale), params: {
      tournament: { name: 'Faction Check', description: 'X', game_system_id: game_systems(:chess).id, format: 'open' }
    }
    t = Tournament::Tournament.order(:created_at).last

    # Register (no faction yet)
    post register_tournament_path(t, locale: I18n.locale)

    # Attempt check-in should be blocked
    post check_in_tournament_path(t, locale: I18n.locale)
    assert_redirected_to tournament_path(t, locale: I18n.locale, tab: 1)

    # Now set faction and allow check-in
    f = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'White')
    reg = t.registrations.find_by(user: @user)
    reg.update!(faction: f)

    post check_in_tournament_path(t, locale: I18n.locale)
    assert_redirected_to tournament_path(t, locale: I18n.locale)
    assert_equal 'checked_in', reg.reload.status
  end

  test 'admin-only and state guards on admin actions' do
    # Creator
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post tournaments_path(locale: I18n.locale),
         params: { tournament: { name: 'X', description: 'Y', game_system_id: game_systems(:chess).id,
                                 format: 'elimination' } }
    t = Tournament::Tournament.order(:created_at).last

    # Not allowed before running
    post next_round_tournament_path(t, locale: I18n.locale)
    assert_redirected_to tournament_path(t, locale: I18n.locale)

    # Lock to running then next round is allowed
    post lock_registration_tournament_path(t, locale: I18n.locale)
    assert_redirected_to tournament_path(t, locale: I18n.locale)
    post next_round_tournament_path(t, locale: I18n.locale)
    assert_redirected_to tournament_path(t, locale: I18n.locale)

    # Non-admin cannot finalize
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale),
         params: { email_address: users(:player_two).email_address, password: 'password' }
    post finalize_tournament_path(t, locale: I18n.locale)
    assert_redirected_to tournament_path(t, locale: I18n.locale)
  end

  test 'elimination bracket tree is generated on lock' do
    creator = users(:player_one)
    p2 = users(:player_two)

    # Sign in as creator and create an elimination tournament
    post session_path(locale: I18n.locale), params: { email_address: creator.email_address, password: 'password' }
    post tournaments_path(locale: I18n.locale), params: {
      tournament: { name: 'KO', description: 'Tree', game_system_id: game_systems(:chess).id, format: 'elimination' }
    }
    t = Tournament::Tournament.order(:created_at).last

    # Creator registers and checks in
    post register_tournament_path(t, locale: I18n.locale)
    f = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'White')
    t.registrations.find_by(user: @user).update!(faction: f)
    post check_in_tournament_path(t, locale: I18n.locale)

    # p2 registers and checks in
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: p2.email_address, password: 'password' }
    post register_tournament_path(t, locale: I18n.locale)
    f2 = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'Black')
    t.registrations.find_by(user: p2).update!(faction: f2)
    post check_in_tournament_path(t, locale: I18n.locale)

    # Lock triggers tree generation
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: creator.email_address, password: 'password' }
    post lock_registration_tournament_path(t, locale: I18n.locale)
    assert_redirected_to tournament_path(t, locale: I18n.locale)

    t.reload
    matches = t.matches
    assert_operator matches.count, :>=, 1

    roots = matches.where(parent_match_id: nil)
    assert_operator roots.count, :>=, 1

    leaves = matches.select { |m| m.child_matches.empty? }
    assert_operator leaves.count, :>=, 1

    if matches.one?
      root = roots.first
      assert root.parent_match.nil?, 'single-match bracket root should have no parent'
      assert root.a_user_id.present? || root.b_user_id.present?, 'single-match bracket should have players'
    else
      first_leaf = leaves.first
      assert first_leaf.a_user_id.present? || first_leaf.b_user_id.present?, 'leaf should have at least one participant'
      assert first_leaf.parent_match.present?, 'leaf should have a parent'
    end
  end

  test 'requires authentication' do
    post tournaments_path(locale: I18n.locale), params: { tournament: { name: 'Nope' } }
    assert_redirected_to new_session_path(locale: I18n.locale)
  end

  test 'guest clicking register gets redirected to login then back to show' do
    t = ::Tournament::Tournament.create!(
      name: 'Public Cup', description: 'Open to all',
      game_system: game_systems(:chess), format: 'open', creator: @user
    )

    # Guest attempts to POST register (simulating clicking the button on the show page)
    post register_tournament_path(t, locale: I18n.locale),
         headers: { 'HTTP_REFERER' => tournament_path(t, locale: I18n.locale) }
    assert_redirected_to new_session_path(locale: I18n.locale)

    # Sign in, should return to tournament show (referer), not POST endpoint
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    follow_redirect!
    assert_response :success
    assert_equal tournament_path(t, locale: I18n.locale), path
  end

  test 'register redirects to participants tab and hides register button when registered' do
    # Sign in and create a swiss tournament
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post tournaments_path(locale: I18n.locale), params: {
      tournament: {
        name: 'Swiss A',
        description: 'S',
        game_system_id: game_systems(:chess).id,
        format: 'swiss',
        rounds_count: 3
      }
    }
    t = Tournament::Tournament.order(:created_at).last

    # Register
    post register_tournament_path(t, locale: I18n.locale)
    assert_redirected_to tournament_path(t, locale: I18n.locale, tab: 1)

    # Visit the participants tab page and ensure register button is not present
    get tournament_path(t, locale: I18n.locale, tab: 1)
    assert_response :success
    assert_no_match(/\b#{Regexp.escape(I18n.t('tournaments.show.register'))}\b/, @response.body)
  end

  test 'next_round generates pairings and blocks when pending matches exist' do
    # Sign in and create a swiss tournament
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post tournaments_path(locale: I18n.locale), params: {
      tournament: {
        name: 'Swiss NR',
        description: 'S',
        game_system_id: game_systems(:chess).id,
        format: 'swiss',
        rounds_count: 2
      }
    }
    t = Tournament::Tournament.order(:created_at).last

    # Register and check in two players
    post register_tournament_path(t, locale: I18n.locale)
    f1 = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'White')
    t.registrations.find_by(user: @user).update!(faction: f1)
    post check_in_tournament_path(t, locale: I18n.locale)
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale),
         params: { email_address: users(:player_two).email_address, password: 'password' }
    post register_tournament_path(t, locale: I18n.locale)
    f2 = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'Black')
    t.registrations.find_by(user: users(:player_two)).update!(faction: f2)
    post check_in_tournament_path(t, locale: I18n.locale)

    # Lock and start first round
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post lock_registration_tournament_path(t, locale: I18n.locale)
    post next_round_tournament_path(t, locale: I18n.locale)

    t.reload
    round1 = t.rounds.order(:number).last
    assert_equal 1, round1.number
    assert_operator round1.matches.count, :>=, 1

    # Attempt to move to next round should fail while match pending
    post next_round_tournament_path(t, locale: I18n.locale)
    assert_redirected_to tournament_path(t, locale: I18n.locale)

    # Report result as participant
    match = round1.matches.first
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale),
         params: { email_address: users(:player_two).email_address, password: 'password' }
    patch tournament_tournament_match_path(t, match, locale: I18n.locale),
          params: { tournament_match: { a_score: 1, b_score: 0 } }
    assert_redirected_to tournament_path(t, locale: I18n.locale, tab: 0)

    # Now moving to next round should work
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post next_round_tournament_path(t, locale: I18n.locale)
    assert_redirected_to tournament_path(t, locale: I18n.locale, tab: 0)
    assert_equal 2, t.rounds.order(:number).last.number
  end

  test 'open link visible for swiss matches to participants and organizer' do
    # Setup swiss tournament with one match
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post tournaments_path(locale: I18n.locale),
         params: { tournament: {
           name: 'Swiss Open',
           description: 'S',
           game_system_id: game_systems(:chess).id,
           format: 'swiss',
           rounds_count: 1
         } }
    t = Tournament::Tournament.order(:created_at).last
    post register_tournament_path(t, locale: I18n.locale)
    f1 = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'White')
    t.registrations.find_by(user: @user).update!(faction: f1)
    post check_in_tournament_path(t, locale: I18n.locale)

    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale),
         params: { email_address: users(:player_two).email_address, password: 'password' }
    post register_tournament_path(t, locale: I18n.locale)
    f2 = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'Black')
    t.registrations.find_by(user: users(:player_two)).update!(faction: f2)
    post check_in_tournament_path(t, locale: I18n.locale)

    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post lock_registration_tournament_path(t, locale: I18n.locale)
    post next_round_tournament_path(t, locale: I18n.locale)

    # Participants see Open link
    get tournament_path(t, locale: I18n.locale, tab: 0)
    assert_includes @response.body, 'Open'

    # Organizer sees Open as well
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    get tournament_path(t, locale: I18n.locale, tab: 0)
    assert_includes @response.body, 'Open'
  end

  test 'reporting swiss match result works like elimination' do
    # Setup swiss
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post tournaments_path(locale: I18n.locale),
         params: { tournament: {
           name: 'Swiss Report',
           description: 'S',
           game_system_id: game_systems(:chess).id,
           format: 'swiss',
           rounds_count: 1
         } }
    t = Tournament::Tournament.order(:created_at).last
    post register_tournament_path(t, locale: I18n.locale)
    f1 = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'White')
    t.registrations.find_by(user: @user).update!(faction: f1)
    post check_in_tournament_path(t, locale: I18n.locale)

    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale),
         params: { email_address: users(:player_two).email_address, password: 'password' }
    post register_tournament_path(t, locale: I18n.locale)
    f2 = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'Black')
    t.registrations.find_by(user: users(:player_two)).update!(faction: f2)
    post check_in_tournament_path(t, locale: I18n.locale)

    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post lock_registration_tournament_path(t, locale: I18n.locale)
    post next_round_tournament_path(t, locale: I18n.locale)

    match = t.rounds.last.matches.first

    # Participant posts result
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale),
         params: { email_address: match.a_user.email_address, password: 'password' }
    patch tournament_tournament_match_path(t, match, locale: I18n.locale),
          params: { tournament_match: { a_score: 0, b_score: 1 } }
    assert_redirected_to tournament_path(t, locale: I18n.locale, tab: 0)

    match.reload
    assert_equal 'b_win', match.result
    assert_not_nil match.game_event_id
  end

  test 'pairings avoid repeats when possible and group by points' do
    # Setup 4 players swiss
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post tournaments_path(locale: I18n.locale), params: {
      tournament: { name: 'Swiss Repeat', description: 'S', game_system_id: game_systems(:chess).id, format: 'swiss' }
    }
    t = Tournament::Tournament.order(:created_at).last

    # Create two additional users
    p3 = User.create!(username: 'player_three', email_address: 'three@example.com', password: 'password')
    p4 = User.create!(username: 'player_four', email_address: 'four@example.com', password: 'password')

    # Register 4 players and check in
    [users(:player_one), users(:player_two), p3, p4].each do |u|
      delete session_path(locale: I18n.locale)
      post session_path(locale: I18n.locale), params: { email_address: u.email_address, password: 'password' }
      post register_tournament_path(t, locale: I18n.locale)
      f = Game::Faction.find_or_create_by!(game_system: t.game_system, name: "F-#{u.username}")
      t.registrations.find_by(user: u).update!(faction: f)
      post check_in_tournament_path(t, locale: I18n.locale)
    end

    # Start tournament
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post lock_registration_tournament_path(t, locale: I18n.locale)

    # Round 1
    post next_round_tournament_path(t, locale: I18n.locale)
    r1_matches = t.rounds.order(:number).last.matches.to_a
    assert_equal 1, t.rounds.order(:number).last.number

    # Report one result so points differ (to create groups)
    m = r1_matches.first
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: m.a_user.email_address, password: 'password' }
    patch tournament_tournament_match_path(t, m, locale: I18n.locale),
          params: { tournament_match: { a_score: 1, b_score: 0 } }

    # Finish the other match too
    other = (r1_matches - [m]).first
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: other.a_user.email_address, password: 'password' }
    patch tournament_tournament_match_path(t, other, locale: I18n.locale),
          params: { tournament_match: { a_score: 1, b_score: 0 } }

    # Round 2 should avoid pairing the same players if possible
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post next_round_tournament_path(t, locale: I18n.locale)

    r2 = t.rounds.order(:number).last
    assert_equal 2, r2.number

    # For each match in R2, ensure it's not a repeat of R1 if possible
    r2.matches.each do |m2|
      repeated = r1_matches.any? do |m1|
        (m1.a_user_id == m2.a_user_id && m1.b_user_id == m2.b_user_id) ||
          (m1.a_user_id == m2.b_user_id && m1.b_user_id == m2.a_user_id)
      end
      assert_not repeated, 'Pairing should avoid repeats when possible'
    end
  end

  test 'swiss pairing fills top spot first and avoids 2-vs-0 when 3 leaders exist' do
    # Create swiss tournament with 8 players
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post tournaments_path(locale: I18n.locale), params: {
      tournament: { name: 'Swiss TopFill', description: 'S', game_system_id: game_systems(:chess).id, format: 'swiss' }
    }
    t = Tournament::Tournament.order(:created_at).last

    # Create 7 additional users
    extra = (3..8).map do |i|
      User.create!(username: "user#{i}", email_address: "user#{i}@example.com", password: 'password')
    end
    all_users = [users(:player_one), users(:player_two)] + extra

    # Register and check-in all
    all_users.each do |u|
      delete session_path(locale: I18n.locale)
      post session_path(locale: I18n.locale), params: { email_address: u.email_address, password: 'password' }
      post register_tournament_path(t, locale: I18n.locale)
      f = Game::Faction.find_or_create_by!(game_system: t.game_system, name: "F-#{u.username}")
      t.registrations.find_by(user: u).update!(faction: f)
      post check_in_tournament_path(t, locale: I18n.locale)
    end

    # Lock
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post lock_registration_tournament_path(t, locale: I18n.locale)

    # Fabricate historical results so that 3 players have 2 points, 2 players have 1, 3 have 0
    u = all_users
    Tournament::Match.create!(tournament: t, a_user: u[0], b_user: u[4], result: 'a_win') # u0 +1
    Tournament::Match.create!(tournament: t, a_user: u[1], b_user: u[5], result: 'a_win') # u1 +1
    Tournament::Match.create!(tournament: t, a_user: u[2], b_user: u[6], result: 'a_win') # u2 +1
    Tournament::Match.create!(tournament: t, a_user: u[0], b_user: u[7], result: 'a_win') # u0 +1 => 2
    Tournament::Match.create!(tournament: t, a_user: u[1], b_user: u[4], result: 'a_win') # u1 +1 => 2
    Tournament::Match.create!(tournament: t, a_user: u[2], b_user: u[5], result: 'a_win') # u2 +1 => 2
    Tournament::Match.create!(tournament: t, a_user: u[3], b_user: u[7], result: 'a_win') # u3 +1 => 1
    Tournament::Match.create!(tournament: t, a_user: u[6], b_user: u[5], result: 'a_win') # u6 +1 => 1

    # Next round: should not produce a 2 vs 0 matchup
    post next_round_tournament_path(t, locale: I18n.locale)
    r = t.rounds.order(:number).last
    assert r.matches.count >= 4

    # Compute points map (including byes if any)
    points = Hash.new(0.0)
    t.matches.find_each do |m|
      case m.result
      when 'a_win'
        points[m.a_user_id] += 1.0 if m.a_user_id
      when 'b_win'
        points[m.b_user_id] += 1.0 if m.b_user_id
      when 'draw'
        if m.a_user_id && m.b_user_id
          points[m.a_user_id] += 0.5
          points[m.b_user_id] += 0.5
        end
      end
    end

    # Ensure no pair is 2 vs 0; at least one pair is 2 vs 2, and at least one is 2 vs 1
    has_2v2 = false
    has_2v1 = false
    r.matches.each do |m|
      next unless m.a_user && m.b_user

      pa2 = (points[m.a_user_id].to_f * 2).round
      pb2 = (points[m.b_user_id].to_f * 2).round
      assert_not ((pa2 == 4 && pb2.zero?) || (pa2.zero? && pb2 == 4)),
                 'Should not pair 2 vs 0'
      has_2v2 ||= pa2 == 4 && pb2 == 4
      has_2v1 ||= (pa2 == 4 && pb2 == 2) || (pa2 == 2 && pb2 == 4)
    end
    assert has_2v2, 'Expected one 2 vs 2 pairing'
    assert has_2v1, 'Expected one 2 vs 1 pairing filling top spot'
  end

  test 'odd participants: lowest-ranked gets bye (non-repeating) and bye counts as one point' do
    # Create swiss tournament with 5 players
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post tournaments_path(locale: I18n.locale), params: {
      tournament: { name: 'Swiss Bye', description: 'S', game_system_id: game_systems(:chess).id, format: 'swiss' }
    }
    t = Tournament::Tournament.order(:created_at).last

    extra = (3..5).map do |i|
      User.create!(username: "bye_user#{i}", email_address: "bye_user#{i}@example.com", password: 'password')
    end
    all_users = [users(:player_one), users(:player_two)] + extra[0, 3]

    # Register and check-in all 5
    all_users.each do |u|
      delete session_path(locale: I18n.locale)
      post session_path(locale: I18n.locale), params: { email_address: u.email_address, password: 'password' }
      post register_tournament_path(t, locale: I18n.locale)
      f = Game::Faction.find_or_create_by!(game_system: t.game_system, name: "F-#{u.username}")
      t.registrations.find_by(user: u).update!(faction: f)
      post check_in_tournament_path(t, locale: I18n.locale)
    end

    # Lock
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post lock_registration_tournament_path(t, locale: I18n.locale)

    # Round 1: expect a bye assigned
    post next_round_tournament_path(t, locale: I18n.locale)
    r1 = t.rounds.order(:number).last
    bye_match1 = r1.matches.find { |m| (m.a_user_id && m.b_user_id.nil?) || (m.b_user_id && m.a_user_id.nil?) }
    assert_not_nil bye_match1, 'Expected a bye match with a single participant'
    bye_user1_id = bye_match1.a_user_id || bye_match1.b_user_id

    # Ensure BYE appears in UI and counts as one point in standings
    get tournament_path(t, locale: I18n.locale, tab: 0)
    assert_includes @response.body, I18n.t('tournaments.show.bye')

    get tournament_path(t, locale: I18n.locale, tab: 2)
    assert_response :success
    body = @response.body
    # Simple check: the bye user should appear with at least 1 point in the table
    assert_match(/#{User.find(bye_user1_id).username}.*?1.0/m, body)

    # Complete the non-bye matches in R1 so we can advance
    r1.matches.each do |m|
      next unless m.a_user && m.b_user

      delete session_path(locale: I18n.locale)
      post session_path(locale: I18n.locale), params: { email_address: m.a_user.email_address, password: 'password' }
      patch tournament_tournament_match_path(t, m, locale: I18n.locale),
            params: { tournament_match: { a_score: 1, b_score: 0 } }
    end

    # Round 2: ensure another bye is not assigned to the same player
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post next_round_tournament_path(t, locale: I18n.locale)
    r2 = t.rounds.order(:number).last
    assert_equal 2, r2.number

    bye_match2 = r2.matches.find { |m| (m.a_user_id && m.b_user_id.nil?) || (m.b_user_id && m.a_user_id.nil?) }
    assert_not_nil bye_match2
    bye_user2_id = bye_match2.a_user_id || bye_match2.b_user_id
    assert_not_equal bye_user1_id, bye_user2_id, 'A bye should not be assigned to the same player twice when avoidable'
  end

  test 'ranking uses points then score sum as tie-break' do
    # Setup swiss with two users and one match with scores
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post tournaments_path(locale: I18n.locale), params: {
      tournament: { name: 'Swiss Rank', description: 'S', game_system_id: game_systems(:chess).id, format: 'swiss' }
    }
    t = Tournament::Tournament.order(:created_at).last

    # Register two users and check in
    [users(:player_one), users(:player_two)].each do |u|
      delete session_path(locale: I18n.locale)
      post session_path(locale: I18n.locale), params: { email_address: u.email_address, password: 'password' }
      post register_tournament_path(t, locale: I18n.locale)
      f = Game::Faction.find_or_create_by!(game_system: t.game_system, name: "F-#{u.username}")
      t.registrations.find_by(user: u).update!(faction: f)
      post check_in_tournament_path(t, locale: I18n.locale)
    end

    # Start first round and play draw with custom scores to force tie-break
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post lock_registration_tournament_path(t, locale: I18n.locale)
    post next_round_tournament_path(t, locale: I18n.locale)

    match = t.rounds.last.matches.first

    # Participant reports draw but with different score sums
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: match.a_user.email_address, password: 'password' }
    patch tournament_tournament_match_path(t, match, locale: I18n.locale),
          params: { tournament_match: { a_score: 3, b_score: 3, result: 'draw' } }

    # Manually adjust scores on event to simulate tie-break by score sum
    match.reload
    event = match.game_event
    a_part = event.game_participations.find_by(user: match.a_user)
    b_part = event.game_participations.find_by(user: match.b_user)
    a_part.update!(score: 10)
    b_part.update!(score: 5)

    # Visit ranking tab and ensure the higher score_sum ranks first
    get tournament_path(t, locale: I18n.locale, tab: 2)
    assert_response :success
    body = @response.body
    first_row = body.split('<tbody>')[1].split('</tbody>')[0].split('<tr>')[1]
    assert_includes first_row, match.a_user.username
  end
end
