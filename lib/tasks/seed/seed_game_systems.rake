# frozen_string_literal: true

namespace :seed do
  task seed_all: :environment do
    Rake::Task['seed:game_systems'].invoke
    Rake::Task['seed:factions'].invoke
  end

  task create_game_systems: :environment do
    if Game::System.find_by(name: 'Epic Armaggeddon - FERC').blank?
      Game::System.create!(
        name: 'Epic Armaggeddon - FERC',
        description: 'Strategy in 6mm - French community-maintained lists'
      )
    end

    if Game::System.find_by(name: 'Warhammer 40k').blank?
      Game::System.create!(
        name: 'Warhammer 40k',
        description: 'The best known Games Workshop game'
      )
    end

    if Game::System.find_by(name: 'The Old World').blank?
      Game::System.create!(
        name: 'The Old World',
        description: 'For square bases enjoyers'
      )
    end

    if Game::System.find_by(name: 'Trench Crusade').blank?
      Game::System.create!(
        name: 'Trench Crusade',
        description: 'Putting the Grim back in Grimdark'
      )
    end
  end

  task create_game_systems: :environment do
    if (Game::System.find_by(name: 'Epic Armaggeddon - FERC') = game).present?
      Game::Faction.create!(
        name: "Space Marines",
        game_system: game
      )
    end

    if Game::System.find_by(name: 'Warhammer 40k').present?
    end

    if Game::System.find_by(name: 'The Old World').present?
    end

    if Game::System.find_by(name: 'Trench Crusade').present?
    end
  end
end
