# frozen_string_literal: true

require 'test_helper'
require 'rake'

class SeedGameSystemsTaskTest < ActiveSupport::TestCase
  def setup
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    
    # Create a temporary YAML file for testing
    @temp_config_path = Rails.root.join('tmp', 'test_game_systems.yml')
    
    # Clean up any existing data
    Game::Faction.destroy_all
    Game::System.destroy_all
  end

  def teardown
    File.delete(@temp_config_path) if File.exist?(@temp_config_path)
    Rake::Task.clear # Reset rake tasks between tests
  end

  test 'seeds game systems and factions from YAML config' do
    create_test_config_file
    stub_config_file_path

    assert_difference 'Game::System.count', 2 do
      assert_difference 'Game::Faction.count', 4 do
        Rake::Task['seed:game_systems'].invoke
      end
    end

    # Verify game systems were created
    chess = Game::System.find_by(name: 'Chess')
    assert_not_nil chess
    assert_equal 'Classic board game', chess.description

    go = Game::System.find_by(name: 'Go')
    assert_not_nil go
    assert_equal 'Ancient strategy game', go.description

    # Verify factions were created
    assert_equal 2, chess.factions.count
    assert chess.factions.pluck(:name).include?('White')
    assert chess.factions.pluck(:name).include?('Black')

    assert_equal 2, go.factions.count
    assert go.factions.pluck(:name).include?('Black Stones')
    assert go.factions.pluck(:name).include?('White Stones')
  end

  test 'does not duplicate existing game systems and factions' do
    create_test_config_file

    # Create existing system and faction
    existing_system = Game::System.create!(name: 'Chess', description: 'Old description')
    existing_faction = Game::Faction.create!(name: 'White', game_system: existing_system)

    stub_config_file_path

    assert_difference 'Game::System.count', 1 do # Only Go should be created
      assert_difference 'Game::Faction.count', 3 do # Black for Chess, and both for Go
        Rake::Task['seed:game_systems'].invoke
      end
    end

    # Verify existing system was updated
    existing_system.reload
    assert_equal 'Classic board game', existing_system.description

    # Verify existing faction was not duplicated
    assert_equal 1, existing_system.factions.where(name: 'White').count
  end

  private

  def create_test_config_file
    config_content = {
      'game_systems' => [
        {
          'name' => 'Chess',
          'description' => 'Classic board game',
          'factions' => ['White', 'Black']
        },
        {
          'name' => 'Go',
          'description' => 'Ancient strategy game',
          'factions' => ['Black Stones', 'White Stones']
        }
      ]
    }

    File.write(@temp_config_path, config_content.to_yaml)
  end

  def stub_config_file_path
    Rails.stubs(:root).returns(Pathname.new(@temp_config_path.dirname))
  end
end