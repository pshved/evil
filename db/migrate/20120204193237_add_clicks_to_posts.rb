class AddClicksToPosts < ActiveRecord::Migration
  def change
    create_table :clicks, :primary_key => :post_id do |t|
      t.references :post
      t.integer :clicks, :default => 0
      t.string :last_click
    end

    add_index :clicks, :post_id

  end
end
