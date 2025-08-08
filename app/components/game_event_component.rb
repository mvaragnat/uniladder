# frozen_string_literal: true

class GameEventComponent < ViewComponent::Base
  def initialize(event:, current_user:)
    super()
    @event = event
    @current_user = current_user
    @participation = event.game_participations.find { |p| p.user_id == current_user.id }
  end

  private

  def other_participants
    @event.players.reject { |u| u.id == @current_user.id }
  end

  def opponent_participation
    @event.game_participations.find { |p| p.user_id != @current_user.id }
  end

  def card_accent_classes
    winner = @event.winner_user
    return 'border-l-4 border-gray-300' if winner.nil?

    winner.id == @current_user.id ? 'border-l-4 border-green-500' : 'border-l-4 border-red-500'
  end
end
