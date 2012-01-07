class CreatePosts < ActiveRecord::Migration
  def change
    create_table :posts do |t|
      t.references :user
      t.references :text_container
      t.string :host
      t.string :unreg_name
      t.references :thread
      t.references :parent
      t.string :subthread_status

      t.timestamps
    end
    add_index :posts, :user_id
    add_index :posts, :text_container_id
    add_index :posts, :thread_id
    add_index :posts, :parent_id
  end
end
