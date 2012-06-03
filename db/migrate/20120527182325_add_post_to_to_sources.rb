class AddPostToToSources < ActiveRecord::Migration
  def change
    add_column :sources, :post_to, :string
  end
end
