class AddHideSignaturesToPresentation < ActiveRecord::Migration
  def change
    add_column :presentations, :hide_signatures, :boolean, :default => false
  end
end
