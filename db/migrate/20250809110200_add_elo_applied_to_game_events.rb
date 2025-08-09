class AddEloAppliedToGameEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :game_events, :elo_applied, :boolean, null: false, default: false
    add_index :game_events, :elo_applied
  end
end 