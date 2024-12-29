# frozen_string_literal: true

require 'test_helper'

module Game
  class EventTest < ActiveSupport::TestCase
    setup do
      @system = game_systems(:chess)
      @user1 = users(:player_one)
      @user2 = users(:player_two)
    end

    test 'should not save event without played_at' do
      event = Game::Event.new(game_system: @system)
      assert_not event.save, 'Saved the event without played_at'
    end

    test 'should not save event without system' do
      event = Game::Event.new(played_at: Time.current)
      assert_not event.save, 'Saved the event without system'
    end

    test 'should create event with one player' do
      event = Game::Event.create!(game_system: @system, played_at: Time.current)
      event.game_participations.create!(user: @user1, result: 'win')
      assert event.valid?
    end

    # test 'should require at least two players' do
    #   event = Game::Event.create!(game_system: @system, played_at: Time.current)
    #   event.participations.create!(user: @user1, result: 'win')
    #   assert_not event.valid?, 'Validated event with only one player'
    # end
  end
end
