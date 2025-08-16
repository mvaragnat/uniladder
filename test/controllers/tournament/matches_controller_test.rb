# frozen_string_literal: true

require 'test_helper'

module Tournament
  class MatchesControllerTest < ActionDispatch::IntegrationTest
    def setup
      @system = game_systems(:chess)
      @creator = users(:player_one)
      @p2 = users(:player_two)
      @p3 = User.create!(username: 'third', email: 'third@example.com', password: 'password')

      EloRating.find_or_create_by!(user: @creator, game_system: @system) do |r|
        r.rating = 1600
        r.games_played = 0
      end
      EloRating.find_or_create_by!(user: @p2, game_system: @system) do |r|
        r.rating = 1500
        r.games_played = 0
      end
      EloRating.find_or_create_by!(user: @p3, game_system: @system) do |r|
        r.rating = 1400
        r.games_played = 0
      end
    end

    test 'winner is propagated to parent after reporting' do
      # Creator signs in and creates elimination tournament
      sign_in @creator
      post tournaments_path(locale: I18n.locale), params: {
        tournament: { name: 'KO', description: 'Tree', game_system_id: @system.id, format: 'elimination' }
      }
      t = ::Tournament::Tournament.order(:created_at).last

      # Register and check in all three players
      post register_tournament_path(t, locale: I18n.locale)
      f1 = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'White')
      t.registrations.find_by(user: @creator).update!(faction: f1)
      post check_in_tournament_path(t, locale: I18n.locale)

      sign_out @creator
      sign_in @p2
      post register_tournament_path(t, locale: I18n.locale)
      f2 = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'Black')
      t.registrations.find_by(user: @p2).update!(faction: f2)
      post check_in_tournament_path(t, locale: I18n.locale)

      sign_out @p2
      sign_in @p3
      post register_tournament_path(t, locale: I18n.locale)
      f3 = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'Third')
      t.registrations.find_by(user: @p3).update!(faction: f3)
      post check_in_tournament_path(t, locale: I18n.locale)

      # Lock (build bracket with a bye for the top seed)
      sign_out @p3
      sign_in @creator
      post lock_registration_tournament_path(t, locale: I18n.locale)

      # Find a leaf with two players (not a bye)
      match = t.matches.select { |m| m.child_matches.empty? && m.a_user_id.present? && m.b_user_id.present? }.first
      assert_not_nil match

      # Report result as one of the participants
      sign_out @creator
      sign_in [match.a_user, match.b_user].first
      patch tournament_tournament_match_path(t, match, locale: I18n.locale),
            params: { tournament_match: { a_score: 5, b_score: 3 } }
      assert_redirected_to tournament_path(t, locale: I18n.locale, tab: 0)

      match.reload
      parent = match.parent_match
      assert_not_nil parent, 'parent should exist'

      winner = match.a_user # since 5 > 3
      side = match.child_slot
      propagated = parent.send("#{side}_user_id")
      assert_equal winner.id, propagated, 'winner should be placed on parent on the same side'

      other_side = side == 'a' ? 'b' : 'a'
      assert parent.send("#{other_side}_user_id").present?, 'other side should be the bye-propagated top seed'
    end
  end
end
