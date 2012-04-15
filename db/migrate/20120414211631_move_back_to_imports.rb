class MoveBackToImports < ActiveRecord::Migration
  def change
    remove_column :posts, :back

    add_column :imports, :back, :string
    add_index :imports, [:source_id,:back]
  end
end
