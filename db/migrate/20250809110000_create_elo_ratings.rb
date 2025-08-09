class CreateEloRatings < ActiveRecord::Migration[8.0]
  def change
    create_table :elo_ratings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :game_system, null: false, foreign_key: { to_table: :game_systems }
      t.integer :rating, null: false, default: 1200
      t.integer :games_played, null: false, default: 0
      t.datetime :last_updated_at
      t.timestamps
    end

    add_index :elo_ratings, %i[user_id game_system_id], unique: true
  end
end 