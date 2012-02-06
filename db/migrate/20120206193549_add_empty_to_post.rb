class AddEmptyToPost < ActiveRecord::Migration
  def change
    add_column :posts, :empty, :boolean

    # Update emptiness of existing posts
    # (we just invoke "save", and a before_save hook will do the trick).
    Posts.all.each {|p| p.save}
  end
end
