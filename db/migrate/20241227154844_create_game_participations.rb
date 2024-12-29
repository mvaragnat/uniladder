class CreateGameParticipations < ActiveRecord::Migration[8.0]
  def change
    create_table :game_participations do |t|
      t.references :game_event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :result, null: false
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :game_participations, [:game_event_id, :user_id], unique: true
  end
end
