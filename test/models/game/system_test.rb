# frozen_string_literal: true

require 'test_helper'

module Game
  class SystemTest < ActiveSupport::TestCase
    test 'should not save system without name' do
      system = Game::System.new(description: 'A game system')
      assert_not system.save, 'Saved the system without a name'
    end

    test 'should not save system without description' do
      system = Game::System.new(name: 'New Game')
      assert_not system.save, 'Saved the system without a description'
    end

    test 'should not save system with duplicate name' do
      game_systems(:chess)
      system = Game::System.new(name: 'Chess', description: 'Another chess game')
      assert_not system.save, 'Saved the system with a duplicate name'
    end
  end
end
