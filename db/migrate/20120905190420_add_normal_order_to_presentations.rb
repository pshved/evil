class AddNormalOrderToPresentations < ActiveRecord::Migration
  def change
    add_column :presentations, :normal_order, :boolean, :default => false
    Presentation.update_all :normal_order => false
  end
end
