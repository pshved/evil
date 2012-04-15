class DropImports < ActiveRecord::Migration
  def change
    drop_table :imports
  end
end
