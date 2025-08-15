# frozen_string_literal: true

namespace :seed do
  task all: :environment do
    Rake::Task['seed:game_systems'].invoke
  end

  task game_systems: :environment do
    config_file = Rails.root.join('config', 'game_systems.yml')
    
    unless File.exist?(config_file)
      puts "Configuration file not found: #{config_file}"
      puts "Please create config/game_systems.yml with your game systems and factions"
      return
    end

    begin
      config = YAML.load_file(config_file)
      game_systems_data = config['game_systems']

      if game_systems_data.blank?
        puts "No game systems found in configuration file"
        return
      end

      puts "Seeding game systems and factions from #{config_file}..."
      
      game_systems_data.each do |system_data|
        seed_game_system(system_data)
      end

      puts "Seeding completed successfully!"
    rescue Psych::SyntaxError => e
      puts "Error parsing YAML file: #{e.message}"
    rescue StandardError => e
      puts "Error seeding game systems: #{e.message}"
    end
  end

  def seed_game_system(system_data)
    system_name = system_data['name']
    system_description = system_data['description']
    factions_data = system_data['factions'] || []

    return if system_name.blank?

    # Find or create game system
    game_system = Game::System.find_by(name: system_name)
    
    if game_system.blank?
      game_system = Game::System.create!(
        name: system_name,
        description: system_description
      )
      puts "✓ Created game system: #{system_name}"
    else
      puts "→ Game system already exists: #{system_name}"
      
      # Update description if it has changed
      if game_system.description != system_description && system_description.present?
        game_system.update!(description: system_description)
        puts "  ↳ Updated description"
      end
    end

    # Seed factions for this game system
    seed_factions(game_system, factions_data)
  end

  def seed_factions(game_system, factions_data)
    return if factions_data.blank?

    factions_data.each do |faction_name|
      next if faction_name.blank?

      existing_faction = game_system.factions.find_by(name: faction_name)
      
      if existing_faction.blank?
        game_system.factions.create!(name: faction_name)
        puts "  ✓ Created faction: #{faction_name}"
      else
        puts "  → Faction already exists: #{faction_name}"
      end
    end
  end
end