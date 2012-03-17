class AddPlusToPresentation < ActiveRecord::Migration
  def change
    add_column :presentations, :plus, :boolean, :default => false
  end
end
