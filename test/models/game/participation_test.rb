# frozen_string_literal: true

require 'test_helper'

module Game
  class ParticipationTest < ActiveSupport::TestCase
    setup do
      @system = game_systems(:chess)
      @user = users(:player_one)
      @user2 = users(:player_two)
      @event = Game::Event.create!(
        game_system: @system,
        played_at: Time.current
      )
    end

    test 'should not save participation without result' do
      participation = Game::Participation.new(game_event_id: @event.id, user: @user)
      assert_not participation.save, 'Saved the participation without a result'
    end

    test 'should not allow duplicate participation in same event' do
      Game::Participation.create!(game_event_id: @event.id, user: @user, result: 'win')
      participation = Game::Participation.new(game_event: @event, user: @user, result: 'loss')
      assert_not participation.save, 'Saved duplicate participation'
    end
  end
end
