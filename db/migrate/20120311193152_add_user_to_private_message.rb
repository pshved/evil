class AddUserToPrivateMessage < ActiveRecord::Migration
  def change
    add_column :private_messages, :user_id, :integer
    add_index :private_messages, :user_id

    # Duplicate all messagea
    PrivateMessage.all.each {|pm| pm.create_duplicate}
  end
end
