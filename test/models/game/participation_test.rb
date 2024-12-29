# frozen_string_literal: true

require 'test_helper'

module Game
  class ParticipationTest < ActiveSupport::TestCase
    setup do
      @system = Game::System.create!(name: 'Chess', description: 'A chess game')
      @event = Game::Event.create!(system: @system, played_at: Time.current)
      @user = User.create!(username: 'player1', email: 'player1@example.com')
    end

    test 'should not save participation without result' do
      participation = Game::Participation.new(event: @event, user: @user)
      assert_not participation.save, 'Saved the participation without a result'
    end

    test 'should not allow duplicate participation in same event' do
      Game::Participation.create!(event: @event, user: @user, result: 'win')
      participation = Game::Participation.new(event: @event, user: @user, result: 'loss')
      assert_not participation.save, 'Saved duplicate participation'
    end
  end
end
