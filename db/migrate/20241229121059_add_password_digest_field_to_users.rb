class AddPasswordDigestFieldToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :password_digest, :string
    
    remove_index :users, :email, unique: true
    rename_column :users, :email, :email_address
    add_index :users, :email_address, unique: true
  end
end
