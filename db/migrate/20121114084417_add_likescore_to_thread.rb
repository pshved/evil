class AddLikescoreToThread < ActiveRecord::Migration
  def change
    add_column :threads, :likescore, :datetime
    add_index :threads, :likescore

    Threads.update_all 'likescore = created_at'
  end
end
