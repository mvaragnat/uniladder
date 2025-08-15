class AddFactionToGameParticipations < ActiveRecord::Migration[8.0]
  def up
    add_reference :game_participations, :faction, foreign_key: { to_table: :game_factions }
  end

  def down
    remove_reference :game_participations, :faction, foreign_key: { to_table: :game_factions }
  end
end 