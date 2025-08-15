# frozen_string_literal: true

require 'test_helper'
require 'rake'

class SeedGameSystemsTaskTest < ActiveSupport::TestCase
  def setup
    Rails.application.load_tasks if Rake::Task.tasks.empty?

    # Backup the original config file if it exists
    @config_file_path = Rails.root.join('config/game_systems.yml')
    @backup_path = Rails.root.join('config/game_systems.yml.backup')

    FileUtils.cp(@config_file_path, @backup_path) if File.exist?(@config_file_path)

    # Clean up any existing data in proper order
    Game::Participation.destroy_all
    Game::Event.destroy_all
    Game::Faction.destroy_all
    Game::System.destroy_all
  end

  def teardown
    # Restore the original config file
    if File.exist?(@backup_path)
      FileUtils.mv(@backup_path, @config_file_path)
    else
      FileUtils.rm_f(@config_file_path)
    end

    Rake::Task.clear # Reset rake tasks between tests
  end

  test 'seeds game systems and factions from YAML config' do
    create_test_config_file

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
    Game::Faction.create!(name: 'White', game_system: existing_system)

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
          'factions' => %w[White Black]
        },
        {
          'name' => 'Go',
          'description' => 'Ancient strategy game',
          'factions' => ['Black Stones', 'White Stones']
        }
      ]
    }

    File.write(@config_file_path, config_content.to_yaml)
  end
end
