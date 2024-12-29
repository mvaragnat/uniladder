class CreateGameEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :game_events do |t|
      t.references :game_system, null: false, foreign_key: true
      t.datetime :played_at, null: false
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :game_events, :played_at
  end
end
