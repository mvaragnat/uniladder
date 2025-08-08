class ReplaceResultWithScoreInParticipations < ActiveRecord::Migration[8.0]
  def change
    add_column :game_participations, :score, :integer
    remove_column :game_participations, :result, :string
  end
end 