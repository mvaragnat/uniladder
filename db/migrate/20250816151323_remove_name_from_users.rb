class RemoveNameFromUsers < ActiveRecord::Migration[8.0]
  def change
    if column_exists?(:users, :name)
      remove_index :users, :name if index_exists?(:users, :name)
      remove_column :users, :name
    end
  end
end
