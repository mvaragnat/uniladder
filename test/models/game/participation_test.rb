# frozen_string_literal: true

require 'test_helper'

module Game
  class ParticipationTest < ActiveSupport::TestCase
    setup do
      @system = game_systems(:chess)
      @user1 = users(:player_one)
      @user2 = users(:player_two)
    end

    test 'should not save participation without score' do
      event = Game::Event.new(game_system: @system, played_at: Time.current)
      event.game_participations.build(user: @user1, score: 21)
      event.game_participations.build(user: @user2) # missing score
      assert_not event.valid?
    end

    test 'should be valid when both scores present' do
      event = Game::Event.new(game_system: @system, played_at: Time.current)
      event.game_participations.build(user: @user1, score: 21)
      event.game_participations.build(user: @user2, score: 18)
      assert event.valid?
    end
  end
end
