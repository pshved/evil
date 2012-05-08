class AddSynchronizedAtToSources < ActiveRecord::Migration
  def change
    add_column :sources, :synchronized_at, :datetime
  end
end
