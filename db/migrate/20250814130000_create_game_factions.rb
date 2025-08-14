class CreateGameFactions < ActiveRecord::Migration[8.0]
	def change
		create_table :game_factions do |t|
			t.references :game_system, null: false, foreign_key: { to_table: :game_systems }
			t.string :name, null: false
			t.timestamps
		end

		add_index :game_factions, [:game_system_id, :name], unique: true
	end
end 