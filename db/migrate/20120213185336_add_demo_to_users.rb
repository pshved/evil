class AddDemoToUsers < ActiveRecord::Migration
  def change
    add_column :users, :demo, :boolean, :default => false
  end
end
