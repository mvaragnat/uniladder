class AddFactionToTournamentRegistrations < ActiveRecord::Migration[8.0]
	def change
		add_reference :tournament_registrations, :faction, null: true, foreign_key: { to_table: :game_factions }
	end
end 