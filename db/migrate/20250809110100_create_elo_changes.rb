class CreateEloChanges < ActiveRecord::Migration[8.0]
  def change
    create_table :elo_changes do |t|
      t.references :game_event, null: false, foreign_key: { to_table: :game_events }
      t.references :user, null: false, foreign_key: true
      t.references :game_system, null: false, foreign_key: { to_table: :game_systems }
      t.integer :rating_before, null: false
      t.integer :rating_after, null: false
      t.decimal :expected_score, precision: 5, scale: 3, null: false
      t.decimal :actual_score, precision: 3, scale: 2, null: false
      t.integer :k_factor, null: false
      t.timestamps
    end

    unless index_exists?(:elo_changes, :game_event_id)
      add_index :elo_changes, :game_event_id, unique: true
    end
    unless index_exists?(:elo_changes, %i[user_id game_system_id])
      add_index :elo_changes, %i[user_id game_system_id]
    end
  end
end 