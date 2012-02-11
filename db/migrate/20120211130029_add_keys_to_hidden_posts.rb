class AddKeysToHiddenPosts < ActiveRecord::Migration
  def change
    add_index :hidden_posts_users, :user_id
    add_index :hidden_posts_users, :posts_id
    add_index :hidden_posts_users, [:user_id,:posts_id], :unique => true
  end
end
