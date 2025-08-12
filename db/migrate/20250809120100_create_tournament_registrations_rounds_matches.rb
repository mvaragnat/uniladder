class CreateTournamentRegistrationsRoundsMatches < ActiveRecord::Migration[8.0]
  def change
    create_table :tournament_registrations do |t|
      t.references :tournament, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :seed
      t.string :status, null: false, default: 'pending' # pending|approved|checked_in
      t.timestamps
    end
    add_index :tournament_registrations, %i[tournament_id user_id], unique: true

    create_table :tournament_rounds do |t|
      t.references :tournament, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :state, null: false, default: 'pending' # pending|pairing|open|closed
      t.datetime :paired_at
      t.datetime :locked_at
      t.timestamps
    end
    add_index :tournament_rounds, %i[tournament_id number], unique: true

    create_table :tournament_matches do |t|
      t.references :tournament, null: false, foreign_key: true
      t.references :tournament_round, foreign_key: true
      t.references :a_user, null: false, foreign_key: { to_table: :users }
      t.references :b_user, null: false, foreign_key: { to_table: :users }
      t.string :result, null: false, default: 'pending' # a_win|b_win|draw|pending
      t.datetime :reported_at
      t.references :game_event, foreign_key: { to_table: :game_events }
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :tournament_matches, %i[tournament_id tournament_round_id]

    add_column :game_events, :tournament_id, :bigint
    add_index :game_events, :tournament_id
    add_foreign_key :game_events, :tournaments
  end
end 