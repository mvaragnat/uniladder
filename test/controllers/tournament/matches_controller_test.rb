# frozen_string_literal: true

require 'test_helper'

module Tournament
  class MatchesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @player1 = users(:player_one)
      @player2 = users(:player_two)
      @system = game_systems(:chess)
    end

    def build_match(format: 'swiss')
      t = ::Tournament::Tournament.create!(
        name: 'T', description: 'D', creator: @player1, game_system: @system, format: format
      )
      r = ::Tournament::Round.create!(tournament: t, number: 1)
      m = ::Tournament::Match.create!(tournament: t, round: r, a_user: @player1, b_user: @player2)
      [t, m]
    end

    test 'draw is accepted for swiss' do
      post session_path(locale: I18n.locale), params: { email_address: @player1.email_address, password: 'password' }
      t, m = build_match(format: 'swiss')

      patch tournament_tournament_match_path(t, m, locale: I18n.locale),
            params: { tournament_match: { a_score: 3, b_score: 3 } }
      assert_redirected_to tournament_tournament_match_path(t, m, locale: I18n.locale)

      m.reload
      assert_equal 'draw', m.result
      assert_not_nil m.game_event_id
    end

    test 'draw is accepted for open' do
      post session_path(locale: I18n.locale), params: { email_address: @player1.email_address, password: 'password' }
      t, m = build_match(format: 'open')

      patch tournament_tournament_match_path(t, m, locale: I18n.locale),
            params: { tournament_match: { a_score: 1, b_score: 1 } }
      assert_redirected_to tournament_tournament_match_path(t, m, locale: I18n.locale)

      m.reload
      assert_equal 'draw', m.result
      assert_not_nil m.game_event_id
    end

    test 'draw is rejected for elimination' do
      post session_path(locale: I18n.locale), params: { email_address: @player1.email_address, password: 'password' }
      t, m = build_match(format: 'elimination')

      patch tournament_tournament_match_path(t, m, locale: I18n.locale),
            params: { tournament_match: { a_score: 2, b_score: 2 } }
      assert_response :unprocessable_entity
      assert_select '#alert', /Draw is not allowed|Draw is not allowed in elimination/

      m.reload
      assert_nil m.game_event_id
      assert_equal 'pending', m.result
    end
  end
end
