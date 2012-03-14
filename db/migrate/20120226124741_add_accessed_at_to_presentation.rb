class AddAccessedAtToPresentation < ActiveRecord::Migration
  def change
    add_column :presentations, :accessed_at, :datetime
    add_index :presentations, :accessed_at
  end
end
