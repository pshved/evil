class AddNameToSources < ActiveRecord::Migration
  def change
    add_column :sources, :name, :string
    add_index :sources, :name
  end
end
