class AddRequestedByToPresentations < ActiveRecord::Migration
  def change
    add_column :presentations, :requested_by, :string
    add_index :presentations, :requested_by
  end
end
