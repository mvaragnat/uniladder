# frozen_string_literal: true

require 'test_helper'

module Tournament
  class TournamentTest < ActiveSupport::TestCase
    setup do
      @creator = users(:player_one)
      @system = game_systems(:chess)
    end

    test 'valid tournament with minimal attributes' do
      t = ::Tournament::Tournament.new(
        name: 'Spring Open',
        creator: @creator,
        game_system: @system,
        format: 'open'
      )
      assert t.valid?
    end

    test 'invalid without name' do
      t = ::Tournament::Tournament.new(
        name: nil,
        creator: @creator,
        game_system: @system,
        format: 'open'
      )
      assert_not t.valid?
      assert t.errors[:name].present?
    end

    test 'invalid with unknown format' do
      t = ::Tournament::Tournament.new(
        name: 'X',
        creator: @creator,
        game_system: @system,
        format: 'league'
      )
      assert_not t.valid?
      assert t.errors[:format].present?
    end

    test 'rounds_count must be positive when provided' do
      t = ::Tournament::Tournament.new(
        name: 'Swiss Cup',
        creator: @creator,
        game_system: @system,
        format: 'swiss',
        rounds_count: 0
      )
      assert_not t.valid?
      assert t.errors[:rounds_count].present?

      t.rounds_count = -1
      assert_not t.valid?
      assert t.errors[:rounds_count].present?

      t.rounds_count = nil
      assert t.valid?
    end
  end
end
