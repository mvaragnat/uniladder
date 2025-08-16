# frozen_string_literal: true

# Helper methods for seeding game systems
module SeedGameSystemsHelper
  def self.run_seeding
    config_file = Rails.root.join('config/game_systems.yml')

    Rails.logger.info 'Seeding game systems from config/game_systems.yml'

    unless File.exist?(config_file)
      Rails.logger.info "Configuration file not found: #{config_file}"
      Rails.logger.info 'Please create config/game_systems.yml with your game systems and factions'
      return
    end

    begin
      config = YAML.load_file(config_file)
      game_systems_data = config['game_systems']

      if game_systems_data.blank?
        Rails.logger.info 'No game systems found in configuration file'
        return
      end

      Rails.logger.info "Seeding game systems and factions from #{config_file}..."

      game_systems_data.each do |system_data|
        seed_game_system(system_data)
      end

      Rails.logger.info 'Seeding completed successfully!'
    rescue Psych::SyntaxError => e
      Rails.logger.info "Error parsing YAML file: #{e.message}"
    rescue StandardError => e
      Rails.logger.info "Error seeding game systems: #{e.message}"
    end
  end

  # Extract a localized value from a string or a hash of locales
  # - Prefers English ('en'), falls back to French ('fr'), then any present value
  def self.localized_value(value)
    return value if value.is_a?(String)
    return value['en'] if value.is_a?(Hash) && value['en'].present?
    return value['fr'] if value.is_a?(Hash) && value['fr'].present?

    value.is_a?(Hash) ? value.values.compact.first : nil
  end

  def self.extract_name(entry)
    case entry
    when String
      entry
    when Hash
      # Can be { 'en' => 'Name', 'fr' => 'Nom' } or { 'name' => { 'en' => 'Name', 'fr' => 'Nom' } }
      if entry.key?('name')
        localized_value(entry['name'])
      else
        localized_value(entry)
      end
    end
  end

  def self.seed_game_system(system_data)
    # Support both legacy mono-lingual strings and new localized hashes
    system_name = extract_name(system_data['name'])
    system_description = localized_value(system_data['description'])
    factions_data = system_data['factions'] || []

    return if system_name.blank?

    # Find or create game system
    game_system = Game::System.find_by(name: system_name)

    if game_system.blank?
      game_system = Game::System.create!(
        name: system_name,
        description: system_description
      )
      Rails.logger.info "✓ Created game system: #{system_name}"
    else
      Rails.logger.info "→ Game system already exists: #{system_name}"

      # Update description if it has changed
      if game_system.description != system_description && system_description.present?
        game_system.update!(description: system_description)
        Rails.logger.info '  ↳ Updated description'
      end
    end

    # Seed factions for this game system
    seed_factions(game_system, factions_data)
  end

  def self.seed_factions(game_system, factions_data)
    return if factions_data.blank?

    factions_data.each do |faction_entry|
      faction_name = extract_name(faction_entry)
      next if faction_name.blank?

      existing_faction = game_system.factions.find_by(name: faction_name)

      if existing_faction.blank?
        game_system.factions.create!(name: faction_name)
        Rails.logger.info "  ✓ Created faction: #{faction_name}"
      else
        Rails.logger.info "  → Faction already exists: #{faction_name}"
      end
    end
  end
end

namespace :seed do
  task game_systems: :environment do
    SeedGameSystemsHelper.run_seeding
  end
end
