# frozen_string_literal: true

require 'test_helper'
require 'rake'

class EloRebuildTaskTest < ActiveSupport::TestCase
  def setup
    @system = game_systems(:chess)
    @user1 = users(:player_one)
    @user2 = users(:player_two)

    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  test 'elo:rebuild reproduces online results' do
    2.times do |i|
      event = Game::Event.new(game_system: @system, played_at: Time.current + i.minutes)
      event.game_participations.build(user: @user1, score: 20 + i)
      event.game_participations.build(user: @user2, score: 15 + i)
      event.save!
      Elo::Updater.new.update_for_event(event)
    end

    online_r1 = EloRating.find_by(user: @user1, game_system: @system).rating
    online_r2 = EloRating.find_by(user: @user2, game_system: @system).rating

    assert_equal online_r1, 1229
    assert_equal online_r2, 1171

    EloRating.destroy_all

    Rake::Task['elo:rebuild'].invoke

    EloRating.find_by(user: @user1, game_system: @system).rating
    EloRating.find_by(user: @user2, game_system: @system).rating

    assert_equal online_r1, 1229
    assert_equal online_r2, 1171
  end
end
