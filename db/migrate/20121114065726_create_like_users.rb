class CreateLikeUsers < ActiveRecord::Migration
  def change
    create_table :like_users do |t|
      t.references :user
      t.references :posts
      t.integer :score

      t.timestamps
    end
    add_index :like_users, :user_id
    add_index :like_users, :posts_id

    add_column :posts, :rating, :integer
  end
end
