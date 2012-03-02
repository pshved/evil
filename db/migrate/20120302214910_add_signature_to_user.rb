class AddSignatureToUser < ActiveRecord::Migration
  def change
    add_column :users, :signature, :integer
    add_index :users, :signature
  end
end
