class CreateModerationActions < ActiveRecord::Migration
  def change
    create_table :moderation_actions do |t|
      t.references :post
      t.references :user
      t.string :reason

      t.timestamps
    end
    add_index :moderation_actions, :post_id
    add_index :moderation_actions, :user_id
  end
end
