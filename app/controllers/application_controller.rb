require 'autoload/utils'
class ApplicationController < ActionController::Base
  protect_from_forgery
  helper_method :current_user_session, :current_user

  private
    def current_user_session
      return @current_user_session if defined?(@current_user_session)
      @current_user_session = UserSession.find
    end

    def current_user
      return @current_user if defined?(@current_user)
      @current_user = current_user_session && current_user_session.user
    end

  def current_presentation(opts = {})
    if u = (current_user ? current_user : opts[:user])
      u.current_presentation(cookies)
    elsif from_cookies = Presentation.from_cookies(cookies)
      # from_cookies may record access time of the presentation
      from_cookies
    else
      if opts[:never_global]
        # If we do not want a global presentation (i.e. we create a new one for an unreg), we should clone it *and* reset if it's global
        p = Presentation.default.clone
        p.global = false
        p
      else
        Presentation.default
      end
    end
  end
  # Allow its use in views (moreover, it's unlikely we'll use it in the controller at all)
  helper_method :current_presentation

  # A convenience helper to get a cache-stamp of something.  This "something" usually has a modification time accessible via "updated_at" and an id.
  def key_of(something,ifnil = 'nil')
    something ? "#{something.id}@#{something.updated_at}" : ifnil
  end
  helper_method :key_of

  # A proxy class that presents a cached thread.  @threads may return either them or real threads.  Cached threads access the ThreadCache object where they get all information to have them rendered.
  class CachedThread
    attr_accessor :presentation, :id, :updated_at
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
      @real_thread ||= Threads.find(id)
      @real_thread.send(sym,*args)
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
    def preload(renderer, force_reload = false)
      if force_reload
        @rendered_threads = self.map {|cached_thread| renderer[cached_thread]}
        index_validator[] if index_validator
      else
        @rendered_threads ||= Rails.cache.fetch("#{cache_key}-html", :expires_in => INDEX_CACHE_TIME, :race_condition_ttl => INDEX_CACHE_UPDATE_TIME) do
          r = self.map {|cached_thread| renderer[cached_thread]}
          index_validator[] if index_validator
          r
        end
      end
    end

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

  # Threads controller action sub.  Used to display threads on the main page
  # The job of this function is to fill the @threads array with indexes (TODO), and to preload the contents of these threads from cache.
  def prepare_threads
    # Try to see if this page for this user is already cached
    # (see fast_tree_cache in PostsHelper for explanation of the cache key)
    cpres = current_presentation
    cache_key = "thread-list.page:#{params[:page]}-sortby:time-user:#{key_of(current_user,'guest')}-view:#{key_of(cpres,'guest')}-global:#{config_mtime}"
    # If a threads cache is invalidated, then re-fetch it
    load_threads = proc do
      logger.info "Rebuilding threads for #{cache_key}"
      # Set up a "Global" view setting, so that the newly created threads comply to it
      Threads.settings_for = current_user
      threads = Threads.order("created_at DESC").page(params[:page])
      thread_page_size = current_presentation.threadpage_size
      threads = threads.per(thread_page_size)
      # Now convert them to cached entities
      cached_threads = threads.map {|t| CachedThread.new(t)}
      # Assign presentation to threads, so we know how to display them
      cached_threads.each {|t| t.presentation = cpres}
      CachedThreadArray.new(cached_threads,cache_key,threads.current_page,threads.num_pages,threads.limit_value)
    end
    unless invalidated_index_pages? then
      # Don't know why but in the development environment this is _always_ a miss!
      @threads = Rails.cache.fetch(cache_key, :expires_in => INDEX_CACHE_TIME, :race_condition_ttl => INDEX_CACHE_UPDATE_TIME,&load_threads)
      # Since Rails 3.1 freezes the objects returned by cache, we have to unfreeze them...
      @threads = @threads.dup.and_unfreeze_kids
      # ^^^ We use "dup" to work-around the fact that Rails cache returns frozen objects.
    else
      @threads = load_threads[]
    end

    # Rails doesn't cache proc objects, so re-initialize it
    @threads.index_validator = proc{ clear_index_invalidation }

    # We do not set up parent, so the login post is new.
    @loginpost = Loginpost.new(:user => current_user)
  end

  # Invalidates index cache for a user.  This should be called from ALL actions that severely modify how an index page looks (i.e. thread folding/unfolding)
  def invalidate_index_pages
    return unless current_user
    Rails.cache.write("invalidation.#{current_user.id}",true,:expires_in => INDEX_CACHE_TIME)
    logger.info "Invalidated for #{current_user.login}"
  end
  def invalidated_index_pages?
    return false unless current_user
    Rails.cache.read("invalidation.#{current_user.id}")
  end
  def clear_index_invalidation
    return unless current_user
    Rails.cache.delete("invalidation.#{current_user.id}")
    logger.info "Invalidation cleared for #{current_user.login}"
  end
  helper_method :invalidated_index_pages?

  public
  # TODO: demo version of 'permission denied page'
  def permission_denied
    # @template is an instance of a helper
    render :partial => 'user_sessions/perm'
  end

  def captcha_enabled
    not (config_param(:recaptcha_public).blank? || config_param(:recaptcha_private).blank?)
  end
  helper_method :captcha_enabled
  def captcha_ok?(opts = {})
    current_user || !captcha_enabled || verify_recaptcha({:model => @loginpost, :private_key => config_param(:recaptcha_private)}.merge(opts))
  end

  # Activity metrics
  # Hint was given here: http://stackoverflow.com/a/9470559/158676
  before_filter :log_request
  protected
  # TODO: can't run without this!  Somehow init.rb is not included everywhere
  ActionController::Base.send :include, Spawn
  # Spawn another thread that will log the proper request
  def log_request
    spawn do
      Activity.create(:host => gethostbyaddr(request.remote_ip))
      # Now cleanup all old activities (NOTE the usage of delete_all instead of destroy_all: we do not need to load them!)
      # This happens only once per several seconds, since it blocks activity database.
      Rails.cache.fetch('activity_delete', :expires_in => ACTIVITY_CACHE_TIME, :race_condition_ttl => ACTIVITY_CACHE_TIME) do
        Activity.delete_all(['created_at < ?', Time.now - config_param(:activity_minutes).minutes])
      end
    end
  end

  # Global admin config modification time
  def config_mtime
    @config_max ||= config_updated_at
  end
  helper_method :config_mtime

  # Since we display login at every page, add a filter that fills it up
  before_filter :new_session_if_unreg, :unless => proc {current_user}
  def new_session_if_unreg
    # The name is different from @user_session because we want to save markup in heaader on login errors.
    @user_session_inline = UserSession.new
  end

  # Methods for configurable
  public
  def clear_config_cache
    Rails.cache.clear
  end
  def config_param(param)
    Rails.cache.fetch("config-#{param}", :expires_in => CONFG_CACHE_TIME) { Configurable[param] }
  end
  helper_method :config_param
  # Get when the global config was updated
  def self.config_updated_at
    Rails.cache.fetch("config-updated-at", :expires_in => CONFG_CACHE_TIME) { Configurable.maximum('updated_at') }
  end
  def config_updated_at
    ApplicationController.config_updated_at
  end

end
