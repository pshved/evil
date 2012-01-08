class Threads < ActiveRecord::Base
  belongs_to :head, :class_name => 'Posts', :autosave => true
  has_many :posts, :class_name => 'Posts', :foreign_key => 'thread_id'

  # Builds a hash of post id => children
  def build_subtree
    ordered = posts.group_by {|p| p.parent.nil?? nil : p.parent.id }
    ordered.each do |parent_id,children|
      children.sort_by!(&:created_at).reverse!
    end
    ordered
  end
end
