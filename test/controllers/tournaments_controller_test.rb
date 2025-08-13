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
    post lock_registration_tournament_path(t, locale: I18n.locale)

    post check_in_tournament_path(t, locale: I18n.locale)
    assert_redirected_to tournament_path(t, locale: I18n.locale)
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
    post check_in_tournament_path(t, locale: I18n.locale)

    # p2 registers and checks in
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: p2.email_address, password: 'password' }
    post register_tournament_path(t, locale: I18n.locale)
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
    post check_in_tournament_path(t, locale: I18n.locale)
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale),
         params: { email_address: users(:player_two).email_address, password: 'password' }
    post register_tournament_path(t, locale: I18n.locale)
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
    post check_in_tournament_path(t, locale: I18n.locale)

    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale),
         params: { email_address: users(:player_two).email_address, password: 'password' }
    post register_tournament_path(t, locale: I18n.locale)
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
    post check_in_tournament_path(t, locale: I18n.locale)

    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale),
         params: { email_address: users(:player_two).email_address, password: 'password' }
    post register_tournament_path(t, locale: I18n.locale)
    post check_in_tournament_path(t, locale: I18n.locale)

    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post lock_registration_tournament_path(t, locale: I18n.locale)
    post next_round_tournament_path(t, locale: I18n.locale)

    match = t.matches.order(:created_at).first

    # Participant posts result
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale),
         params: { email_address: users(:player_two).email_address, password: 'password' }
    patch tournament_tournament_match_path(t, match, locale: I18n.locale),
          params: { tournament_match: { a_score: 0, b_score: 1 } }
    assert_redirected_to tournament_path(t, locale: I18n.locale, tab: 0)

    match.reload
    assert_equal 'b_win', match.result
    assert_not_nil match.game_event_id
  end

  test 'my tournaments lists tournaments where I am the creator' do
    # Sign in
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }

    # Create two tournaments by me, one by someone else
    mine1 = ::Tournament::Tournament.create!(
      name: 'Mine 1', description: 'A', game_system: game_systems(:chess),
      format: 'open', creator: @user
    )
    mine2 = ::Tournament::Tournament.create!(
      name: 'Mine 2', description: 'B', game_system: game_systems(:chess),
      format: 'swiss', rounds_count: 3, creator: @user
    )
    ::Tournament::Tournament.create!(
      name: 'Other', description: 'C', game_system: game_systems(:chess),
      format: 'open', creator: users(:player_two)
    )

    get tournaments_path(locale: I18n.locale)
    assert_response :success

    assert_includes @response.body, mine1.name
    assert_includes @response.body, mine2.name
  end

  test 'admin can change strategies and they persist' do
    post session_path(locale: I18n.locale), params: { email_address: @user.email_address, password: 'password' }
    post tournaments_path(locale: I18n.locale), params: {
      tournament: { name: 'Strategies', description: 'S', game_system_id: game_systems(:chess).id, format: 'swiss' }
    }
    t = Tournament::Tournament.order(:created_at).last

    patch tournament_path(t, locale: I18n.locale), params: {
      tournament: {
        pairing_strategy_key: 'by_points_random_within_group',
        tiebreak1_strategy_key: 'score_sum',
        tiebreak2_strategy_key: 'none'
      }
    }
    assert_redirected_to tournament_path(t, locale: I18n.locale, tab: 3)

    t.reload
    assert_equal 'by_points_random_within_group', t.pairing_strategy_key
    assert_equal 'score_sum', t.tiebreak1_strategy_key
    assert_equal 'none', t.tiebreak2_strategy_key
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
