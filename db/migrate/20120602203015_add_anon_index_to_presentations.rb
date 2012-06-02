class AddAnonIndexToPresentations < ActiveRecord::Migration
  def change
    add_index :presentations, [:cookie_key]
  end
end
