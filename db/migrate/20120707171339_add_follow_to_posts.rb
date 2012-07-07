class AddFollowToPosts < ActiveRecord::Migration

  class SmallPosts < ActiveRecord::Base
    set_table_name "posts"
    belongs_to :text_container, :autosave => true
    def title
      text_container.unescaped[0]
    end
  end

  def change
    add_column :posts, :follow, :string

    # Do not update timestamps or something during the migration
    ActiveRecord::Base.record_timestamps = false
    # Update emptiness of existing posts
    # (we just invoke "save", and a before_save hook will do the trick).
    SmallPosts.find(:all, :include => [:text_container]).each do |p|
      if md = RegexpConvertNode.match_url_in(p.title.html_safe)
        p.follow = md[0]
        p.save
      end
    end
  end
end
