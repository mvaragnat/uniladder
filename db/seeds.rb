# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Seed default factions for demo systems
if defined?(Game::System)
  chess = Game::System.find_by(name: 'Chess')
  if chess
    %w[White Black].each do |name|
      Game::Faction.find_or_create_by!(game_system: chess, name: name)
    end
  end

  go = Game::System.find_by(name: 'Go')
  if go
    %w[Black White].each do |name|
      Game::Faction.find_or_create_by!(game_system: go, name: name)
    end
  end
end
