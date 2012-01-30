class AddBackToPost < ActiveRecord::Migration
  def change
    add_column :posts, :back, :string
    add_index :posts, :back
  end
end
