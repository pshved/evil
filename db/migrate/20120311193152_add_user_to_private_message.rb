class AddUserToPrivateMessage < ActiveRecord::Migration
  def change
    add_column :private_messages, :user_id, :integer
    add_index :private_messages, :user_id
    add_column :private_messages, :unread, :boolean, :default => false

    # Duplicate all messagea
    PrivateMessage.all.each {|pm| pm.create_duplicate}

    PrivateMessage.update_all :unread => false
  end
end
