class Threads < ActiveRecord::Base
  belongs_to :head, :class_name => 'Posts', :autosave => true
  has_many :posts, :class_name => 'Posts', :foreign_key => 'thread_id'

  # Builds a hash of post id => children
  def build_subtree
    ensure_subtree_cache
    @cached_subtree
  end

  # Show what posts are auto-hidden in this thread
  def hides
    ensure_subtree_cache
    @cached_hides
  end

  # As this model does not persist across requests, we may safely cache it
  protected; def ensure_subtree_cache
    unless @cached_subtree
      @cached_subtree, @cached_hides = compute_thread(posts)
    end
  end
  public

  # Index optimization
  # Fast posts fetcher only stores titles
  has_many :faster_posts,
    :class_name => 'FasterPost',
    :finder_sql => proc { "select posts.id, text_items.body as title, posts.created_at, posts.empty_body, posts.parent_id, posts.marks, posts.unreg_name, users.login as user_login, posts.host, clicks.clicks, hidden_posts_users.action as hide_action, text_containers.updated_at as cache_timestamp,
      deleted
    from posts
    join text_containers on posts.text_container_id = text_containers.id
    join text_items on (text_items.text_container_id = text_containers.id) and (text_items.revision = text_containers.current_revision)
    left join users on posts.user_id = users.id
    left join clicks on clicks.post_id = posts.id
    left join hidden_posts_users on hidden_posts_users.user_id = #{settings_for ? settings_for.id : 'NULL'} and hidden_posts_users.posts_id = posts.id
    where text_items.number = 0
      and thread_id = #{id}" }

  # Faster subtree getters
  # Builds a hash of post id => children
  def build_subtree_fast
    ensure_subtree_fast_cache
    @cached_subtree_fast
  end

  # Show what posts are auto-hidden in this thread
  # NOTE that hides_fast creates the cache, so the thread view settings *MUST* have already been supplied!
  def hides_fast
    ensure_subtree_fast_cache
    @cached_hides_fast
  end

  def self.settings_for=(sf)
    @@settings_for = sf
  end
  def settings_for
    @@settings_for
  end

  attr_accessor :presentation
  def presentation
    @presentation || Presentation.default
  end

  # As this model does not persist across requests, we may safely cache it
  protected; def ensure_subtree_fast_cache
    unless @cached_subtree_fast
      @cached_subtree_fast, @cached_hides_fast = compute_thread(faster_posts)
    end
  end
  public

  # When displaying many threads, even showing first posts in them may be slow.  This function returns thread's head in fast form.
  # NOTE: it fetches the whole thread into fast cache!
  def fast_head
    ensure_subtree_fast_cache
    @cached_subtree_fast[nil][0]
  end

  protected
  def compute_thread(posts_assoc = posts)
    # Build if not cached
    raw_list = posts_assoc
    idmap = posts_assoc.inject({}){|acc,p| acc[p.id] = p; acc}
    # Build id => children mapping, and order it as in threads
    ordered = posts_assoc.group_by &:parent_value
    ordered.each do |parent_id,children|
      children.sort_by!(&:created_at).reverse!
    end
    r_subtree = ordered

    # compute raw id tree
    idtree = ordered.inject({}) {|acc,kv| acc[kv[0]] = kv[1].map &:id ; acc}

    # Compute thread information.  Keys are IDs, values are hashes with the following info:
    # { :latest => post, # the latest post in the subthread of the node
    #   :hidden => true, # whether the subtherad is automatically hidden based on hide threshold/value
    #   :smoothed => true, # whether the *children* of this node should be displayed at the same level as it, based on smooth threshold value
    #   :size => N, # How many posts are there, in the subthread
    # }
    thread_info = {}
    # We wanted to cache them, but, in production environment, models are not re-loadedd at each request
    threshold = presentation.autowrap_thread_threshold
    value = presentation.autowrap_thread_value
    smooth_threshold = presentation.smooth_threshold
    smooth_threshold = nil if smooth_threshold.blank?
    # NOTE: these are local variables, and they won't work within "def", so we pass them as local

    # Walks the tree, and returns the information about the subthread, which is a hash:
    # { :latest_id => ID of the latest post,
    #   :latest_mtime => modification time of the latest post,
    #   :height => height of the subtree
    #   :size => number of nodes in the subtree
    def walk(node,tree,idmap,thread_info,threshold,value,smooth_threshold,depth = 0,is_an_only_child = false)
      depth += 1
      return {:height => 0, :size => 0} unless node

      # The walking function is organized as follows:
      # 1. Collect information from the children
      # 2. Compute and upload the information about the current node
      # 3. Prepare the return value for the parent

      # 1. Collect information from children
      kids = tree[node] || []
      kids_info = kids.map {|child| walk(child,tree,idmap,thread_info,threshold,value,smooth_threshold,depth,kids.length == 1)}
      # Generalize the information
      r = {}
      r[:height] = ( kids_info.map{|ki| ki[:height]}.max || 0)
      kids_info.each do |ki|
        if r[:latest_mtime].nil? || r[:latest_mtime] < ki[:latest_mtime]
          r[:latest_mtime] = ki[:latest_mtime]
          r[:latest_id] = ki[:latest_id]
        end
      end

      # 2. Compute and upload the information about the current node
      # Check if the thread should be hidden
      hidden = threshold && depth && ((depth + r[:height]) > threshold) && (depth == value)
      # Check if the thread should be smoothed
      # We smooth a thread if the thread is deep enough, if the thread has an only kid, and if the thread is an only child.
      smoothed = smooth_threshold && (depth >= smooth_threshold) && (kids.length == 1) && is_an_only_child
      # Sum the size
      size = kids_info.inject(1) {|acc,ki| acc + (ki[:size] || 0)}

      thread_info[node] = {:latest => idmap[r[:latest_id]], :hidden => hidden, :smoothed => smoothed, :size => size}

      # 3. Prepare the return value for the parent
      created_at = idmap[node].created_at
      if r[:latest_mtime].nil? || r[:latest_mtime] < created_at
        r[:latest_mtime] = created_at
        r[:latest_id] = node
      end
      r[:height] += 1
      r[:size] = size

      r
    end
    # Do the walk
    walk(idtree[nil][0],idtree,idmap,thread_info,threshold,value,smooth_threshold)

    # For backward compatibility, let's return hides
    r_hides = thread_info

    return r_subtree, r_hides
  end
end
