class AddPostedToAtToThreads < ActiveRecord::Migration
  def change
    add_column :threads, :posted_to_at, :datetime
    add_index :threads, :posted_to_at

    # Calculate this for all threads
    Threads.all.each do |t|
      t.posted_to_at = t.posts.maximum(:created_at)
      t.save
    end
  end
end
