class FixPostEmptyColumn < ActiveRecord::Migration
  def change
    rename_column :posts, :empty, :empty_body
  end
end
