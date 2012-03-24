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

  # Threads controller action sub.  Used to display threads on the main page
  def prepare_threads
    # Set up a "Global" view setting, so that the newly created threads comply to it
    Threads.settings_for = current_user
    @threads = Threads.order("created_at DESC").page(params[:page])
    thread_page_size = current_presentation.threadpage_size
    @threads = @threads.per(thread_page_size)
    # Assign presentation to threads, so we know how to display them
    cpres = current_presentation
    @threads.each {|t| t.presentation = cpres}
    # We do not set up parent, so the login post is new.
    @loginpost = Loginpost.new(:user => current_user)
  end

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
      Activity.delete_all(['created_at < ?', Time.now - config_param(:activity_minutes).minutes])
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
