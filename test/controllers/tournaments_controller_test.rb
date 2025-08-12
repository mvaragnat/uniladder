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
    post generate_pairings_tournament_path(t, locale: I18n.locale)
    assert_redirected_to tournament_path(t, locale: I18n.locale)

    # Lock to running then generate is allowed
    post lock_registration_tournament_path(t, locale: I18n.locale)
    assert_redirected_to tournament_path(t, locale: I18n.locale)
    post generate_pairings_tournament_path(t, locale: I18n.locale)
    assert_redirected_to tournament_path(t, locale: I18n.locale)

    # Non-admin cannot close or finalize
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale),
         params: { email_address: users(:player_two).email_address, password: 'password' }
    post close_round_tournament_path(t, locale: I18n.locale)
    assert_redirected_to tournament_path(t, locale: I18n.locale)
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
end
