class AddMarksToPost < ActiveRecord::Migration
  def change
    add_column :posts, :marks, :string
  end
end
