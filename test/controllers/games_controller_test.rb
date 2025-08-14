# frozen_string_literal: true

require 'test_helper'

class GamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:player_one)
    @system = game_systems(:chess)
    @opponent = users(:player_two)
    post session_path, params: { email_address: @user.email_address, password: 'password' }

    @f1 = Game::Faction.find_or_create_by!(game_system: @system, name: 'White')
    @f2 = Game::Faction.find_or_create_by!(game_system: @system, name: 'Black')
  end

  test 'should get new game form' do
    get new_game_event_path
    assert_response :success
    assert_select 'h2', text: I18n.t('games.new.title')
  end

  test 'should create game' do
    assert_difference 'Game::Event.count' do
      post game_events_path, params: {
        game_event: {
          game_system_id: @system.id,
          game_participations_attributes: [
            { user_id: @user.id, score: 21, faction_id: @f1.id },
            { user_id: @opponent.id, score: 18, faction_id: @f2.id }
          ]
        }
      }
    end

    assert_redirected_to dashboard_path(locale: I18n.locale)
  end

  test 'should not create game with invalid params' do
    post game_events_path, params: {
      game_event: {
        game_system_id: nil,
        game_participations_attributes: []
      }
    }

    assert_response :unprocessable_entity
  end

  test 'should not create game if a score is missing' do
    post game_events_path, params: {
      game_event: {
        game_system_id: @system.id,
        game_participations_attributes: [
          { user_id: @user.id, score: 21, faction_id: @f1.id },
          { user_id: @opponent.id, faction_id: @f2.id }
        ]
      }
    }

    assert_response :unprocessable_entity
  end

  test 'should not create game without players' do
    post game_events_path, params: {
      game_event: {
        game_system_id: @system.id,
        game_participations_attributes: []
      }
    }

    assert_response :unprocessable_entity
  end
end
