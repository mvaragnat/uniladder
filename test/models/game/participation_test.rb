# frozen_string_literal: true

require 'test_helper'

module Game
  class ParticipationTest < ActiveSupport::TestCase
    setup do
      @system = game_systems(:chess)
      @user1 = users(:player_one)
      @user2 = users(:player_two)
      @f1 = Game::Faction.find_or_create_by!(game_system: @system, name: 'White')
      @f2 = Game::Faction.find_or_create_by!(game_system: @system, name: 'Black')
    end

    test 'should not save participation without score' do
      event = Game::Event.new(game_system: @system, played_at: Time.current)
      event.game_participations.build(user: @user1, score: 21, faction: @f1)
      event.game_participations.build(user: @user2) # missing score
      assert_not event.valid?
    end

    test 'should be valid when both scores present' do
      event = Game::Event.new(game_system: @system, played_at: Time.current)
      event.game_participations.build(user: @user1, score: 21, faction: @f1)
      event.game_participations.build(user: @user2, score: 18, faction: @f2)
      assert event.valid?
    end

    test 'requires faction' do
      system = game_systems(:chess)
      f = Game::Faction.find_or_create_by!(game_system: system, name: 'White')

      event = Game::Event.new(game_system: system, played_at: Time.current)
      event.game_participations.build(user: users(:player_one), score: 10, faction: f)
      event.game_participations.build(user: users(:player_two), score: 8)

      assert_not event.valid?
      assert_includes event.errors.full_messages.join, I18n.t('games.errors.both_factions_required')
    end
  end
end
