# frozen_string_literal: true

class AddBracketTreeToTournamentMatches < ActiveRecord::Migration[8.0]
  def change
    change_column_null :tournament_matches, :a_user_id, true
    change_column_null :tournament_matches, :b_user_id, true

    add_reference :tournament_matches, :parent_match, foreign_key: { to_table: :tournament_matches }, index: true
    add_column :tournament_matches, :child_slot, :string
  end
end 