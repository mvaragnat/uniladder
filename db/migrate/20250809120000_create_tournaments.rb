class CreateTournaments < ActiveRecord::Migration[8.0]
  def change
    create_table :tournaments do |t|
      t.string :name, null: false
      t.text :description
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :game_system, null: false, foreign_key: { to_table: :game_systems }
      t.string :format, null: false # open|swiss|elimination
      t.integer :rounds_count
      t.datetime :starts_at
      t.datetime :ends_at
      t.string :state, null: false, default: 'draft'
      t.jsonb :settings, null: false, default: {}
      t.string :slug
      t.timestamps
    end

    add_index :tournaments, :slug, unique: true
  end
end 