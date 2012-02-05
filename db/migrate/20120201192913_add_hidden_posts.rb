class AddHiddenPosts < ActiveRecord::Migration
  def change
    create_table :hidden_posts_users, :id => false do |t|
      t.integer :user_id
      t.integer :posts_id
    end
  end
end
