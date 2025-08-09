# frozen_string_literal: true

namespace :elo do
  desc 'Rebuild Elo ratings from all events (optionally for a system: SYSTEM_ID=ID)'
  task rebuild: :environment do
    system_id = ENV['SYSTEM_ID']&.to_i

    puts 'Resetting Elo tables...'
    EloRating.delete_all
    EloChange.delete_all

    scope = Game::Event.order(:played_at)
    scope = scope.where(game_system_id: system_id) if system_id.present? && system_id.positive?

    puts "Recomputing Elo for #{scope.count} events..."
    scope.find_each do |event|
      event.update!(elo_applied: false)
      Elo::Updater.new.update_for_event(event)
    end

    puts 'Done.'
  end
end
