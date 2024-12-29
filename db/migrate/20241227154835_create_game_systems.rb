class CreateGameSystems < ActiveRecord::Migration[8.0]
  def change
    create_table :game_systems do |t|
      t.string :name, null: false
      t.text :description, null: false

      t.timestamps
    end
    
    add_index :game_systems, :name, unique: true
  end
end
