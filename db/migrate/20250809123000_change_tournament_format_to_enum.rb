# frozen_string_literal: true

class ChangeTournamentFormatToEnum < ActiveRecord::Migration[8.0]
  def change
    change_column :tournaments, :format, :integer
    change_column_null :tournaments, :format, false
    change_column_default :tournaments, :format, from: nil, to: 0
    add_index :tournaments, :format unless index_exists?(:tournaments, :format)
  end
end 