class AddUnreadToPrivateMessage < ActiveRecord::Migration
  def change
    add_column :private_messages, :unread, :boolean, :default => false

    PrivateMessage.update_all :unread => false
  end
end
