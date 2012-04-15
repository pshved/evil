class AddReplyToToImports < ActiveRecord::Migration
  def change
    add_column :imports, :reply_to, :string
    add_index :imports, [:source_id,:reply_to]
  end
end
