class AddActionToHiddenPostsUsers < ActiveRecord::Migration
  def change
    drop_table :hidden_posts_users

    create_table "hidden_posts_users" do |t|
      t.integer "user_id"
      t.integer "posts_id"
      t.enum :action, :limit => [:show,:hide]
    end

    add_index "hidden_posts_users", ["posts_id"], :name => "index_hidden_posts_users_on_posts_id"
    add_index "hidden_posts_users", ["user_id", "posts_id"], :name => "index_hidden_posts_users_on_user_id_and_posts_id"
    add_index "hidden_posts_users", ["user_id"], :name => "index_hidden_posts_users_on_user_id"
  end
end
