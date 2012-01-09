class CreatePrivateMessages < ActiveRecord::Migration
  def change
    create_table :private_messages do |t|
      t.references :sender_user
      t.references :recipient_user
      t.references :text_container
      t.references :reply_to
      t.string :stamp

      t.timestamps
    end
    add_index :private_messages, :sender_user_id
    add_index :private_messages, :recipient_user_id
    add_index :private_messages, :text_container_id
    add_index :private_messages, :reply_to_id
    add_index :private_messages, :stamp
  end
end
