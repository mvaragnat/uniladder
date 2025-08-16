# frozen_string_literal: true

class DropLegacyAuth < ActiveRecord::Migration[8.0]
  def change
    # Remove sessions table
    drop_table :sessions, if_exists: true

    # Remove legacy columns and indexes from users
    if column_exists?(:users, :email_address)
      remove_index :users, :email_address if index_exists?(:users, :email_address)
      remove_column :users, :email_address
    end

    if column_exists?(:users, :password_digest)
      remove_column :users, :password_digest
    end
  end
end


