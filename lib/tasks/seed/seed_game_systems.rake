# frozen_string_literal: true

namespace :seed do
  task create_game_systems: :environment do
    if Game::System.find_by(name: 'Epic Armaggeddon - FERC').blank?
      Game::System.create!(
        name: 'Epic Armaggeddon - FERC',
        description: 'The 6mm strategy game, in its v4 iteration - French league'
      )
    end
  end
end
