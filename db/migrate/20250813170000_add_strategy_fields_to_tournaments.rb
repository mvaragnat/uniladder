# frozen_string_literal: true

class AddStrategyFieldsToTournaments < ActiveRecord::Migration[7.2]
	def change
		add_column :tournaments, :pairing_strategy_key, :string, null: false, default: 'by_points_random_within_group'
		add_column :tournaments, :tiebreak1_strategy_key, :string, null: false, default: 'score_sum'
		add_column :tournaments, :tiebreak2_strategy_key, :string, null: false, default: 'none'
	end
end 