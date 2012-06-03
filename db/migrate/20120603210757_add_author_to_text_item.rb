class AddAuthorToTextItem < ActiveRecord::Migration
  def change
    add_column :text_items, :user_id, :integer
    add_index :text_items, :user_id
  end
end
