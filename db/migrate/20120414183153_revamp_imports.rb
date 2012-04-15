class RevampImports < ActiveRecord::Migration
  def change
    create_table :imports do |t|
      t.references :post
      t.references :source

      t.timestamps
    end
    add_index :imports, :post_id
    add_index :imports, :source_id
  end
end
