class AddInstantToSources < ActiveRecord::Migration
  def change
    add_column :sources, :instant, :boolean
  end
end
