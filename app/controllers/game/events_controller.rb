# frozen_string_literal: true

module Game
  class EventsController < ApplicationController
    def new
      @game = Event.new
      @game.game_participations.build(user: Current.user)
    end

    def create
      @game = Event.new(game_params)
      @game.played_at = Time.current

      respond_to do |format|
        if @game.save
          format.turbo_stream do
            component_html = view_context.render(GameEventComponent.new(event: @game, current_user: Current.user))
            render turbo_stream: [
              turbo_stream.remove('no-games-message'),
              turbo_stream.prepend('games-list', component_html),
              turbo_stream.replace('modal', '')
            ]
          end
          format.html { redirect_to dashboard_path, notice: t('.success') }
        else
          format.turbo_stream { render :new, status: :unprocessable_entity }
          format.html { render :new, status: :unprocessable_entity }
        end
      end
    end

    private

    def game_params
      key = params.key?(:event) ? :event : :game_event
      params.require(key).permit(
        :game_system_id,
        game_participations_attributes: %i[user_id score]
      )
    end
  end
end
