# frozen_string_literal: true

class EloUpdateJob < ApplicationJob
  queue_as :default

  def perform(game_event_id)
    event = Game::Event.find_by(id: game_event_id)
    return unless event

    Elo::Updater.new.update_for_event(event)
  end
end
