class AddCreatedAtIndexToThreads < ActiveRecord::Migration
  def change
    add_index :threads, :created_at
  end
end
