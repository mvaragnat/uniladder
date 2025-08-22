# frozen_string_literal: true

class AddSecondaryScoreToGameParticipations < ActiveRecord::Migration[8.0]
  def change
    add_column :game_participations, :secondary_score, :integer
  end
end


