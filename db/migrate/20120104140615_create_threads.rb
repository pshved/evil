class CreateThreads < ActiveRecord::Migration
  def change
    create_table :threads do |t|
      t.references :head
      t.datetime :updated_at
      t.datetime :created_at
    end
    add_index :threads, :head_id
  end
end
