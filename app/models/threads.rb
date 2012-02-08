class Threads < ActiveRecord::Base
  belongs_to :head, :class_name => 'Posts', :autosave => true
  has_many :posts, :class_name => 'Posts', :foreign_key => 'thread_id'

  # Index optimization
  # Fast posts fetcher only stores titles
  has_many :faster_posts,
    :class_name => 'FasterPost',
    :finder_sql => proc { "select posts.id, text_items.body as title, posts.created_at, posts.empty, posts.parent_id, posts.marks, posts.unreg_name, users.login as user_login, posts.host, clicks.clicks
    from posts
    join text_containers on posts.text_container_id = text_containers.id
    join text_items on (text_items.text_container_id = text_containers.id) and (text_items.revision = text_containers.current_revision)
    left join users on posts.user_id = users.id
    left join clicks on clicks.post_id = posts.id
    where text_items.number = 0 and thread_id = #{id}" }

  # Builds a hash of post id => children
  def build_subtree
    # As this model does not persist across requests, we may safely cache it
    compute_thread unless @cached_subtree
    @cached_subtree
  end

  # Show what posts are auto-hidden in this thread
  def hides
    compute_thread unless @cached_hides
    @cached_hides
  end

  protected
  def compute_thread
    # Build if not cached
    ordered = faster_posts.group_by &:parent_value
    ordered.each do |parent_id,children|
      children.sort_by!(&:created_at).reverse!
    end
    @cached_subtree = ordered

    # compute raw id tree
    idtree = ordered.inject({}) {|acc,kv| acc[kv[0]] = kv[1].map &:id ; acc}

    # This is not used _now_, but we may need it later
    # Compute id => subtree height hash
    #def compute_height(tree,node, c = {})
    #  return c[node] if c[node]
    #  if !node || !tree[node] || tree[node].empty?
    #    c[node] = 1
    #  else
    #    c[node] = 1 + tree[node].map {|kid| compute_height(tree,kid)}.max
    #  end
    #end
    #subtree_heights = idtree.inject({}){|acc,kv| acc[kv[0]] = compute_height(idtree,kv[0]); acc }

    # Compute hides.  In the hash specified as the 3rd param the nodes that should be hidden will appear
    def compute_hides(tree,node,r,threshold,value,current = 1)
      return true  if current > threshold
      return false if !node || !tree[node]
      # Compute for kids (do not forget that we're to upload r here
      # NOTE the absence of short-circuit evaluation, as we do not want first children to prevent the late from being folded
      big_subtree = tree[node].inject(false) {|acc,kid| acc | compute_hides(tree,kid,r,threshold,value,current + 1)}
      r[node] = true if current == value && big_subtree
      big_subtree
    end
    hides = {}
    threshold = Configurable[:autowrap_thread_threshold]
    value = Configurable[:autowrap_thread_value]
    compute_hides(idtree,idtree[nil][0],hides,threshold,value)
    @cached_hides = hides
  end
end
