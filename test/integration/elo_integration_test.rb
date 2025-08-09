# frozen_string_literal: true

require 'test_helper'

class EloIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @system = game_systems(:chess)
    @user1 = users(:player_one)
    @user2 = users(:player_two)
  end

  test 'creating a valid event applies elo' do
    post game_events_path, params: {
      event: {
        game_system_id: @system.id,
        game_participations_attributes: [
          { user_id: @user1.id, score: 21 },
          { user_id: @user2.id, score: 18 }
        ]
      }
    }

    event = Game::Event.order(:created_at).last
    Elo::Updater.new.update_for_event(event)

    r1 = EloRating.find_by(user: @user1, game_system: @system)
    r2 = EloRating.find_by(user: @user2, game_system: @system)
    assert_not_nil r1
    assert_not_nil r2
  end

  # rubocop:disable Metrics/BlockLength
  test 'backfill produces same results as online updates' do
    2.times do |i|
      post game_events_path, params: {
        event: {
          game_system_id: @system.id,
          game_participations_attributes: [
            { user_id: @user1.id, score: 20 + i },
            { user_id: @user2.id, score: 15 + i }
          ]
        }
      }
    end

    Game::Event.where(game_system: @system).order(:played_at).find_each do |event|
      Elo::Updater.new.update_for_event(event)
    end

    online_r1 = EloRating.find_by(user: @user1, game_system: @system).rating
    online_r2 = EloRating.find_by(user: @user2, game_system: @system).rating

    EloRating.delete_all
    EloChange.delete_all
    Game::Event.where(game_system: @system).find_each { |e| e.update!(elo_applied: false) }
    Game::Event.where(game_system: @system).order(:played_at).find_each do |event|
      Elo::Updater.new.update_for_event(event)
    end

    rebuilt_r1 = EloRating.find_by(user: @user1, game_system: @system).rating
    rebuilt_r2 = EloRating.find_by(user: @user2, game_system: @system).rating

    assert_equal online_r1, rebuilt_r1
    assert_equal online_r2, rebuilt_r2
  end
  # rubocop:enable Metrics/BlockLength

  test 'concurrent updates serialize safely' do
    event1 = Game::Event.new(game_system: @system, played_at: Time.current)
    event1.game_participations.build(user: @user1, score: 22)
    event1.game_participations.build(user: @user2, score: 20)
    event1.save!

    event2 = Game::Event.new(game_system: @system, played_at: Time.current)
    event2.game_participations.build(user: @user1, score: 18)
    event2.game_participations.build(user: @user2, score: 19)
    event2.save!

    threads = []
    threads << Thread.new { Elo::Updater.new.update_for_event(event1) }
    threads << Thread.new { Elo::Updater.new.update_for_event(event2) }
    threads.each(&:join)

    r1 = EloRating.find_by(user: @user1, game_system: @system)
    r2 = EloRating.find_by(user: @user2, game_system: @system)
    assert_not_nil r1
    assert_not_nil r2
  end
end
