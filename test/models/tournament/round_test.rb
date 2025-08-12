# frozen_string_literal: true

require 'test_helper'

module Tournament
  class RoundTest < ActiveSupport::TestCase
    setup do
      @t = ::Tournament::Tournament.create!(
        name: 'Swiss Cup',
        creator: users(:player_one),
        game_system: game_systems(:chess),
        format: 'swiss',
        rounds_count: 3
      )
    end

    test 'valid with number' do
      r = ::Tournament::Round.new(tournament: @t, number: 1)
      assert r.valid?
    end

    test 'invalid without number' do
      r = ::Tournament::Round.new(tournament: @t)
      assert_not r.valid?
      assert r.errors[:number].present?
    end
  end
end
