# frozen_string_literal: true

require 'test_helper'

class EloIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @creator = users(:player_one)
    @player2 = users(:player_two)
    @system = game_systems(:chess)
  end

  test 'tournament registration, lock, pairing and result reporting' do
    # Creator signs in and creates a swiss tournament
    post session_path(locale: I18n.locale), params: { email_address: @creator.email_address, password: 'password' }
    assert_response :redirect

    post tournaments_path(locale: I18n.locale), params: {
      tournament: {
        name: 'Swiss Challenge',
        description: 'Test swiss',
        game_system_id: @system.id,
        format: 'swiss',
        rounds_count: 3
      }
    }
    assert_response :redirect
    t = ::Tournament::Tournament.order(:created_at).last

    # Creator registers and checks in
    post register_tournament_path(t, locale: I18n.locale)
    assert_response :redirect
    post check_in_tournament_path(t, locale: I18n.locale)
    assert_response :redirect

    # Another player registers and checks in
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: @player2.email_address, password: 'password' }
    assert_response :redirect
    post register_tournament_path(t, locale: I18n.locale)
    assert_response :redirect
    post check_in_tournament_path(t, locale: I18n.locale)
    assert_response :redirect

    # Creator locks registration and generates pairings
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: @creator.email_address, password: 'password' }
    post lock_registration_tournament_path(t, locale: I18n.locale)
    assert_response :redirect
    post generate_pairings_tournament_path(t, locale: I18n.locale)
    assert_response :redirect

    match = t.matches.order(:created_at).last
    assert_not_nil match

    # Non-participant cannot report
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: 'one@example.com', password: 'password' }
    patch tournament_tournament_match_path(t, match, locale: I18n.locale),
          params: { tournament_match: { a_score: 1, b_score: 0 } }
    assert_redirected_to tournament_tournament_match_path(t, match, locale: I18n.locale)

    # Participant can report
    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: @player2.email_address, password: 'password' }
    patch tournament_tournament_match_path(t, match, locale: I18n.locale),
          params: { tournament_match: { a_score: 1, b_score: 0 } }
    assert_redirected_to tournament_tournament_match_path(t, match, locale: I18n.locale)

    match.reload
    assert_equal 'a_win', match.result
    event_id = match.game_event_id
    assert_not_nil event_id

    # After reported, only organizer can modify
    patch tournament_tournament_match_path(t, match, locale: I18n.locale),
          params: { tournament_match: { a_score: 0, b_score: 1 } }
    assert_redirected_to tournament_tournament_match_path(t, match, locale: I18n.locale)
    match.reload
    assert_equal 'a_win', match.result

    delete session_path(locale: I18n.locale)
    post session_path(locale: I18n.locale), params: { email_address: @creator.email_address, password: 'password' }
    patch tournament_tournament_match_path(t, match, locale: I18n.locale),
          params: { tournament_match: { a_score: 0, b_score: 1 } }
    assert_redirected_to tournament_tournament_match_path(t, match, locale: I18n.locale)
    match.reload
    assert_equal 'b_win', match.result
  end
end
