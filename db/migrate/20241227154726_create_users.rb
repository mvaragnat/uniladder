class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :email, null: false
      t.string :name

      t.timestamps
    end
    
    add_index :users, :username, unique: true
    add_index :users, :email, unique: true
  end
end