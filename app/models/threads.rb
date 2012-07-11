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
  # Fast posts fetcher only stores titles.  The parameter is the ID of the user.
  def faster_posts(settings_for = self.settings_for)
    @preloaded_posts || FasterPost.sql_posts(settings_for ? settings_for.id : nil).where(['thread_id = ?', id])
  end
  # You may also preload posts for this thread externally, say, via a cached thread (see below)
  attr_accessor :preloaded_posts

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

  attr_accessor :presentation
  def presentation
    @presentation || Presentation.default
  end
  attr_accessor :settings_for

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
    (@cached_subtree_fast[nil] || [])[0]
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

    # Remove items hidden from the tree, according to the user's settings.
    # This removes the posts that are deleted, and the posts from pazuzued users (banned for this current user)
    banned_users = settings_for ? settings_for.pazuzus : []
    # This function returns a hash of post ids that should be removed from the view.
    def remove_unnecessary(node,tree,idmap,banned_users)
      return {} unless node
      kids = tree[node] || []

      # Get all removed posts in the subthread
      removed_sub = kids.inject([]) {|acc, kid| acc + remove_unnecessary(kid,tree,idmap,banned_users)}
      # Get the remainig kids
      remaining_kids = kids - removed_sub

      # Check if this post is banned
      post_invis = banned_users.inject(false) {|acc, bu| acc || bu.bans(idmap[node])}
      removed_sub << node if post_invis && remaining_kids.empty?

      removed_sub
    end

    # Apply override of pazuzued users here
    banned_users_for_remove = (settings_for && settings_for.nopazuzu) ? [] : banned_users

    # Select posts to remove
    to_remove = remove_unnecessary(idtree[nil][0],idtree,idmap,banned_users_for_remove)

    idtree = idtree.inject({}) {|acc, kv| acc[kv[0]] = (kv[1] || []) - to_remove; acc}
    # Now get back the tree that maps ids to arrays of the actual posts, not their IDs
    r_subtree = idtree.inject({}) do |acc, kv|
      new_value = (kv[1] || []).map{|i| idmap[i]}.compact
      acc[kv[0]] = new_value unless new_value.empty?
      acc
    end

    # NOTE: at this point, we have formed the data to handle.  The rest is actually related to the "view" part, and might be decoupled in the future.

    # Compute thread information.  Keys are IDs, values are hashes with the following info:
    # { :latest => post, # the latest post in the subthread of the node
    #   :hidden => true, # whether the subtherad is automatically hidden based on hide threshold/value
    #   :smoothed => true, # whether the *children* of this node should be displayed at the same level as it, based on smooth threshold value
    #   :size => N, # How many posts are there, in the subthread
    #   :has_nonempty_body => true, Whether the subthread (or the post itself) contains a post with a nonempty body
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
    #   :has_nonempty_body => true, Whether the subthread (or the post itself) contains a post with a nonempty body
    def walk(node,tree,idmap,thread_info,threshold,value,smooth_threshold,banned_users = [],depth = 0,is_an_only_child = false)
      depth += 1
      return {:height => 0, :size => 0} unless node

      # The walking function is organized as follows:
      # 1. Collect information from the children
      # 2. Compute and upload the information about the current node
      # 3. Prepare the return value for the parent

      # 1. Collect information from children
      kids = tree[node] || []
      kids_info = kids.map {|child| walk(child,tree,idmap,thread_info,threshold,value,smooth_threshold,banned_users,depth,kids.length == 1)}
      # Generalize the information
      r = {}
      r[:height] = ( kids_info.map{|ki| ki[:height]}.max || 0)
      kids_info.each do |ki|
        if r[:latest_mtime].nil? || r[:latest_mtime] < ki[:latest_mtime]
          r[:latest_mtime] = ki[:latest_mtime]
          r[:latest_id] = ki[:latest_id]
        end
      end
      any_kids_nonempty = kids_info.inject(false) {|acc,ki| acc || ki[:has_nonempty_body]}

      # 2. Compute and upload the information about the current node
      # Check if the thread should be hidden
      hidden = threshold && depth && ((depth + r[:height]) > threshold) && (depth == value)
      # Check if the thread should be smoothed
      # We smooth a thread if the thread is deep enough, if the thread has an only kid, and if the thread is an only child.
      smoothed = smooth_threshold && (depth >= smooth_threshold) && (kids.length == 1) && is_an_only_child
      # Sum the size
      size = kids_info.inject(1) {|acc,ki| acc + (ki[:size] || 0)}
      has_nonempty_body = !idmap[node].empty_body? || any_kids_nonempty
      pazuzued = banned_users.inject(false) {|acc, bu| acc || bu.bans(idmap[node])}

      thread_info[node] = {
        :latest => idmap[r[:latest_id]],
        :hidden => hidden,
        :smoothed => smoothed,
        :size => size,
        :has_nonempty_body => has_nonempty_body,
        :pazuzued => pazuzued,
      }

      # 3. Prepare the return value for the parent
      created_at = idmap[node].created_at
      if r[:latest_mtime].nil? || r[:latest_mtime] < created_at
        r[:latest_mtime] = created_at
        r[:latest_id] = node
      end
      r[:height] += 1
      r[:size] = size
      r[:has_nonempty_body] = has_nonempty_body

      r
    end
    # Do the walk
    # (we apply "banned_users" here regardless of whether we hide them)
    walk(idtree[nil][0],idtree,idmap,thread_info,threshold,value,smooth_threshold,banned_users)

    # For backward compatibility, let's return hides
    r_hides = thread_info

    return r_subtree, r_hides
  end

  #### THREAD LISTING CACHING FUNCTIONALITY ###
  # A proxy class that presents a cached thread.  @threads may return either them or real threads.  Cached threads access the ThreadCache object where they get all information to have them rendered.
  class CachedThread
    attr_accessor :presentation, :id, :updated_at, :settings_for
    # Given a "normal" thread, initialize
    def initialize(thread)
      self.id = thread.id
      self.updated_at = thread.updated_at
    end

    attr_accessor :parent_index, :parent
    # Get the HTML for this thread from cache.  The thread_renderer is a proc object that renders a thread if it's not found in cache.  This is used to render _all_ threads on the page!
    # If +force_reload+ is set, it forces to query the cache for each thread separately, and update those that are too old.  Most threads, however, will remain cached.
    def cached_html(thread_renderer,force_reload = false)
      parent.get_rendered(parent_index,thread_renderer,force_reload)
    end

    # If we are trying to access a missing method, we just forward it to the "read" thread
    def method_missing(sym,*args)
      # You'll need it to see what things to build into the cached thread
      #puts "DEBUG: CachedThread method_missing #{sym}"
      real_thread.send(sym,*args)
    end

    # Allow other entities (such as CachedThreadArray) convey the real thread here
    def real_thread=(thr)
      @real_thread = thr
      # We should also send the settings proxied by the current thread to the new one
      @real_thread.presentation = self.presentation
      @real_thread.settings_for = self.settings_for
      @real_thread
    end
    private
    # Load the real thread, and convey the presentation to it
    def real_thread
      return @real_thread if @real_thread
      self.real_thread = Threads.find(id)
    end
  end

  class CachedThreadArray < Array
    # Fake the thread object

    # These accessors are responsible for faking a paginatable object.  See Kaminari's paginate method to see what we're to fake
    attr_accessor :current_page, :num_pages, :limit_value

    # This is an accessor to the thr
    attr_accessor :cache_key, :index_validator

    # Create the object.  Index_validator should be inserted manually!
    def initialize(array,cache_key,cp,np,lv)
      super(array.length)
      self.current_page = cp
      self.num_pages = np
      self.limit_value = lv
      array.each_with_index {|o,i| self[i]=o}
      # Convey the index in the array to items
      notify_children
      # Save the cache key for threads preloading
      self.cache_key = cache_key
    end

    private
    def notify_children
      # Convey the index in the array to items
      self.each_with_index {|cached_thread,i| cached_thread.parent_index = i; cached_thread.parent = self}
    end

    public
    def preloaded
      ! self.rendered_threads.nil?
    end
    # Preload the layout of the threads to the cache.  The +renderer+ is a proc that takes a thread and returns HTML for it.
    # We assume that calling a renderer for a thread will load it from DB.  This assumption allows us to get all threads at the first call to the renderer
    def preload(renderer, force_reload = false)
      if force_reload
        preload_all_threads_sql
        @rendered_threads = self.map {|cached_thread| renderer[cached_thread]}
        # Save the updated thread selection to the cache
        Rails.cache.write("#{cache_key}-html", @rendered_threads, :expires_in => INDEX_CACHE_TIME, :race_condition_ttl => INDEX_CACHE_UPDATE_TIME)
        index_validator[] if index_validator
      else
        @rendered_threads ||= Rails.cache.fetch("#{cache_key}-html", :expires_in => INDEX_CACHE_TIME, :race_condition_ttl => INDEX_CACHE_UPDATE_TIME) do
          preload_all_threads_sql
          r = self.map {|cached_thread| renderer[cached_thread]}
          index_validator[] if index_validator
          r
        end
      end
    end

    # To be used by controller: since we're now able to preload all threads in one SQL, we need the user to fetch settings for
    attr_accessor :settings_for
    private
    # Make "faster_posts" for all threads in this array preloaded
    def preload_all_threads_sql
      return @preload_all_threads_sql if @preload_all_threads_sql
      # Fetch hashes of thread and post objects
      @preloaded_all_threads = Threads.where(:id => self.map(&:id)).group_by {|t| t.id}
      @preloaded_all_posts = FasterPost.sql_posts(@settings_for ? @settings_for.id : nil).where(:thread_id => self.map(&:id)).group_by{|p| p.thread_id}
      # Put this into threads
      self.each.map {|thr| thr.real_thread = @preloaded_all_threads[thr.id][0]}
      self.each.map {|thr| thr.preloaded_posts = @preloaded_all_posts[thr.id]}
    end

    public
    def get_rendered(i,thread_renderer,force_reload = false)
      preload(thread_renderer,force_reload)
      @rendered_threads[i]
    end

    # Since Rails 3.1 freezes the objects returned by cache, we have to unfreeze them.  This unfreezes the array items by duplicating them.  Returns self.
    def and_unfreeze_kids
      self.map! &:dup
      # Now the unfrozen kids point to the old, frozen parent.  Re-notify them.
      notify_children
      self
    end
  end

end
