# frozen_string_literal: true

require 'test_helper'

class EloIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @system = game_systems(:chess)
    @user1 = users(:player_one)
    @user2 = users(:player_two)
  end

  test 'creating a valid event applies elo' do
    assert_nil EloRating.find_by(user: @user1, game_system: @system)
    assert_nil EloRating.find_by(user: @user2, game_system: @system)

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
    assert_equal 1215, r1.rating
    assert_equal 1185, r2.rating
  end

  test 'concurrent updates serialize safely' do
    assert_nil EloRating.find_by(user: @user1, game_system: @system)
    assert_nil EloRating.find_by(user: @user2, game_system: @system)

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

    # Final ratings are {1199, 1201} in some order depending on thread scheduling
    assert_equal [1199, 1201], [r1.rating, r2.rating].sort
  end
end
