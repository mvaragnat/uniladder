# frozen_string_literal: true

require 'test_helper'

module Game
  class EventTest < ActiveSupport::TestCase
    setup do
      @system = game_systems(:chess)
      @user1 = users(:player_one)
      @user2 = users(:player_two)
      @f1 = Game::Faction.find_or_create_by!(game_system: @system, name: 'White')
      @f2 = Game::Faction.find_or_create_by!(game_system: @system, name: 'Black')
    end

    test 'should not save event without played_at' do
      event = Game::Event.new(game_system: @system)
      assert_not event.save, 'Saved the event without played_at'
    end

    test 'should not save event without system' do
      event = Game::Event.new(played_at: Time.current)
      assert_not event.save, 'Saved the event without system'
    end

    test 'should be invalid with fewer than two players' do
      event = Game::Event.new(game_system: @system, played_at: Time.current)
      event.game_participations.build(user: @user1, score: 21, faction: @f1)
      assert_not event.valid?
      assert_includes event.errors[:players], I18n.t('games.errors.exactly_two_players')
    end

    test 'should be valid with exactly two players and scores' do
      event = Game::Event.new(game_system: @system, played_at: Time.current)
      event.game_participations.build(user: @user1, score: 21, faction: @f1)
      event.game_participations.build(user: @user2, score: 18, faction: @f2)
      assert event.valid?
    end

    test 'winner_user returns the user with the highest score' do
      event = Game::Event.new(game_system: @system, played_at: Time.current)
      event.game_participations.build(user: @user1, score: 21, faction: @f1)
      event.game_participations.build(user: @user2, score: 18, faction: @f2)
      event.save!
      assert_equal @user1, event.winner_user
    end

    test 'winner_user returns nil on draw' do
      event = Game::Event.new(game_system: @system, played_at: Time.current)
      event.game_participations.build(user: @user1, score: 10, faction: @f1)
      event.game_participations.build(user: @user2, score: 10, faction: @f2)
      event.save!
      assert_nil event.winner_user
    end
  end
end
