require 'autoload/utils'
require 'activity_tracker'
class ApplicationController < ActionController::Base
  protect_from_forgery
  # Page rendering time utils (must be at the beginning)
  before_filter { @page_start_time = Time.now.to_f }
  helper_method :page_load_time
  def page_load_time
    sprintf('%.3f', (Time.now.to_f - @page_start_time))
  end

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
        # NOTE: no need to cache here; it's a write operation
        p = Presentation.default.clone
        p.global = false
        p
      else
        Rails.cache.fetch('default_pres', :expires_in => CONFG_CACHE_TIME) {Presentation.default}
      end
    end
  end
  # Allow its use in views (moreover, it's unlikely we'll use it in the controller at all)
  helper_method :current_presentation

  # CSRF protection: POST requests are protected, this is used for GET protection.  Merge the result of get_csrf_token to params hash, and call verify_get_csrf as a before filter before actions.
  def get_csrf_token
    if current_user
      { :gctok => current_user.persistence_token }
    else
      {}
    end
  end
  helper_method :get_csrf_token
  def verify_get_csrf
    if current_user
      permission_denied unless params[:gctok] == current_user.persistence_token
    else
      # Someone's doing something nasty, deny permissions
      permission_denied unless params[:gctok].blank?
    end
  end

  # A convenience helper to get a cache-stamp of something.  This "something" usually has a modification time accessible via "updated_at" and an id.
  def key_of(something,ifnil = 'nil')
    something ? "#{something.id}@#{something.updated_at}" : ifnil
  end
  helper_method :key_of

  # Returns cache key for a thread object thr.  Gets necessary information from the environment
  def thread_cache_key(thr,presentation)
    # The wat a thread is displayed depends on many factors.
    # - thread itself (identified by id and modification time);
    # - the user's presentation (identified by its id and mtime... for now.  Later)
    # - the user's show/hide for this thread (currently induced by the presentation anyway).
    # - the current thread (this is fixed by a kludgy regexp).
    # - global configuration of the site (modification time of it);
    # - the user itself (as a tracker for its pazuzus)
    # x user's timezone (this is accounted for in the presentations)
    # x what post we are showing (it's @post).  This will be replaced via CSS.
    # TODO: Later, these rules may be replaced with whether the user has touched the thread, but it's fast enough now
    thread_key = key_of thr
    user_key = key_of(current_user,'guest')
    presentation_key = key_of presentation
    "tree-thread:#{thread_key}-view:#{presentation_key}-global:#{config_mtime}-user:#{user_key}-#{@show_all_posts}-#{@nopazuzu}"
  end
  helper_method :thread_cache_key

  # Threads controller action sub.  Used to display threads on the main page
  # The job of this function is to fill the @threads array with indexes (TODO), and to preload the contents of these threads from cache.
  def prepare_threads
    # Try to see if this page for this user is already cached
    # (see fast_tree_cache in PostsHelper for explanation of the cache key)
    cpres = current_presentation
    # A mockup of thread sorting options
    sort_threads = (params[:thread_order] || 'create').to_sym
    cache_key = "thread-list.page:#{params[:page]}-sortby:#{sort_threads}-user:#{key_of(current_user,'guest')}-view:#{key_of(cpres,'guest')}-global:#{config_mtime}"
    # If a threads cache is invalidated, then re-fetch it
    load_threads = proc do
      logger.info "Rebuilding threads for #{cache_key}"
      # Set up a "Global" view setting, so that the newly created threads comply to it
      threads = Threads
      if sort_threads == :create
        threads = threads.order("created_at DESC")
      elsif sort_threads == :like
        threads = threads.order("likescore DESC")
      else
        threads = threads.order("posted_to_at DESC")
      end
      threads = threads.page(params[:page])
      thread_page_size = current_presentation.threadpage_size
      threads = threads.per(thread_page_size)
      # Now convert them to cached entities
      cached_threads = threads.map {|t| Threads::CachedThread.new(t)}
      Threads::CachedThreadArray.new(cached_threads,cache_key,threads.current_page,threads.num_pages,threads.limit_value)
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
    # Assign presentation information to threads, so the model now knows how to display them
    @threads.settings_for = current_user
    # HACK HACK HACK!  This is used to convey this to thread layout builder.  Accounted for in cache separately
    if current_user
      @nopazuzu = !params[:nopazuzu].blank?
      @threads.settings_for.nopazuzu = @nopazuzu if current_user
    end
    # END of hack
    @threads.each {|t| t.presentation = cpres}
    @threads.each {|t| t.settings_for = current_user}

    # Rails doesn't cache proc objects, so re-initialize it
    clear_index_invalidation

    # Select the thread contents from cache.  Cache hits will give us exactly the views that should be rendered.  Cache misses will indicate the therads that should be reloaded.
    # Result: hash thread_id => rendered thread/nil.
    @threads.each {|t| t.cached_html = Rails.cache.read(thread_cache_key(t,cpres), :expires_in => THREAD_CACHE_TIME)}

    # Select threads that can't be fetched from cache
    non_cached_threads = []
    @threads.each{|t| non_cached_threads << t.id unless t.cached_html}

    puts "Threads not cached = #{non_cached_threads.length}"

    # Load all the relevant threads
    @threads.preload_all_threads_sql

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

  # TODO: can't run spawn without this!  Somehow init.rb is not included everywhere
  ActionController::Base.send :include, Spawn

  # Activity metrics
  # Hint was given here: http://stackoverflow.com/a/9470559/158676
  # We use after filter in order to not delay the delievery of the data
  after_filter :log_request
  protected
  # We track activity like this.  At each request, we record it into memcached (spawning a thread for this takes much more time than just doing it at once).  The place we record the click to is identified by the current time.  This allows for some imprecision due to read/write race conditions.
  # Each several seconds, a job wakes up, collects all the information from the memcached activity storage spawned within the previous time span we track activity for (this allows us to ignore old data, and do it on a per-request basis instead of maintaining a cron job), and commits it to MySQL's `activities` table.
  def log_request
    access_tracker.event()
    # Activities are committed periodically, via the external API call.  See ApiController and config/schedule.rb.

    # Notify the sources as well
    notify_sources
  end

  # Commit activity data if we're in development mode
  if Rails.env.to_sym == :development
    after_filter do
      access_tracker.commit
      post_clicks_tracker.commit
      source_request_tracker.commit
    end
  end

  public
  def access_tracker
    period = config_param(:activity_minutes).minutes
    @access_tracker ||= ActivityTracker.new(
      :tick =>ACTIVITY_CACHE_TICK,
      :period => period,
      :commit_period => ACTIVITY_CACHE_TIME,
      :width => ACTIVITY_CACHE_WIDTH,
      :scope => 'site_wide_activity',
      :read_proc => proc {
        h = Rails.cache.fetch('activity_hosts', :expires_in => ACTIVITY_CACHE_TIME) {Activity.select('distinct host').where(['created_at >= ?', Time.now - period]).count}
        c = Rails.cache.fetch('activity_clicks', :expires_in => ACTIVITY_CACHE_TIME) {Activity.select('host').where(['created_at >= ?', Time.now - period]).count}
        [h, c]
      },
      :update_proc => proc {|activity_data|
        host = gethostbyaddr(request.remote_ip)
        # Double braces because we add an array of 2 elements into an array of arrays
        (activity_data || []) + [[Time.now, host]]
      },
      :commit_proc => proc {|records|
        # Convert these records to ActiveRecord initialization hashes
        # Unfortunately, even if we use something like "Activity.create(inits)", we'll create a lot of transactions/DB inserts anyway.  We have to resort to raw SQL to use a single, multi-row insert :-(
        # (or, install ActiveRecord-extensions gem, but it would be used here only)
        unless records.empty?
          inserts = records.inject([]) {|acc, rec| acc + ["('#{rec[1]}','#{rec[0].to_formatted_s(:db)}')"]}
          # NOTE: keep this synchronized with +click!+
          Activity.connection.execute "INSERT into activities(host,created_at) VALUES #{inserts.join(", ")}"
        end
        # Also, delete old activities that aren't interesting anymore
        Activity.delete_all(['created_at < ?', Time.now - period])
      },
    )
  end
  helper_method :access_tracker

  def post_clicks_tracker
    @post_clicks_tracker ||= ActivityTracker.new(
      :tick => POST_CLICK_CACHE_TIME,
      :period => POST_CLICK_CACHE_TIME,
      :commit_period => POST_CLICK_CACHE_TIME,
      :width => POST_CLICK_CACHE_WIDTH,
      :scope => 'post_clicks_activity',
      # We don't need to read anything, we read from the database when we render posts
      :update_proc => proc {|activity_data, post_id|
        clicker = Click.clicker(current_user,request.remote_ip)
        # We record the click time to "replay" post clicks at commit, ordered by time
        # Double braces because we add an array of 2 elements into an array of arrays
        (activity_data || []) + [[Time.now, post_id, clicker]]
      },
      :commit_proc => proc {|records|
        # Clicks model has an abstraction of "replaying" a click sequence.  Just pass it there.
        # Sort by click time, and remove the time
        click_sequence = records.sort {|a,b| a[0] <=> b[0]}.map{|id_time_host| id_time_host[1..2]}
        Click.replay(click_sequence)
      },
    )
  end

  def source_request_tracker
    @source_request_tracker ||= ActivityTracker.new(
      :tick => SOURCE_UPDATE_CACHE_TIME,
      :period => SOURCE_UPDATE_CACHE_TIME,
      :commit_period => SOURCE_UPDATE_CACHE_TIME,
      :width => SOURCE_UPDATE_CACHE_WIDTH,
      :scope => 'source_rq_tr',
      :update_proc => proc {|activity_data, source|
        # add "true" to an easier conversion to hash
        (activity_data || []) + [ [source, true] ]
      },
      :commit_proc => proc {|records|
        Source.record_accesses_to(Hash[records].keys)
      },
    )
  end

  protected
  # Notify the DB that sources shown in this view that were requested.
  # NOTE: temporarily, we access all sources!  Later, we make this distinguish between the sources a user actually tries to display
  def notify_sources
    sources = Rails.cache.fetch('sources_to_notify') { Source.all.map &:id }
    sources.each{|s| source_request_tracker.event(s)}
  end

  protected

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
