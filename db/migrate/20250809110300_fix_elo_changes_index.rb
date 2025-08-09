class FixEloChangesIndex < ActiveRecord::Migration[8.0]
  def change
    if index_exists?(:elo_changes, :game_event_id, unique: true)
      remove_index :elo_changes, column: :game_event_id
    end

    add_index :elo_changes, %i[game_event_id user_id], unique: true unless index_exists?(:elo_changes, %i[game_event_id user_id], unique: true)
  end
end 