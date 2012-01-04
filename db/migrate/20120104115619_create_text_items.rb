class CreateTextItems < ActiveRecord::Migration
  def up
    create_table :text_items do |t|
      t.references :text_container
      t.integer :revision
      t.integer :number
      t.text :body

      t.timestamps

    end

    change_table :text_items do |t|
      # What we'll search for when looking at the content
      t.index [:text_container_id, :revision], :name => 'k_rev_id'
      t.index [:text_container_id, :revision, :number], :name => 'k_rev_i_id', :unique => true
      t.index [:text_container_id]
    end
  end

  def down
    drop_table :text_items
  end
end
