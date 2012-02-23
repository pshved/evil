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

  # Threads controller action sub.  Used to display threads on the main page
  def prepare_threads
    # Set up a "Global" view setting, so that the newly created threads comply to it
    Threads.settings_for = current_user
    @threads = Threads.order("created_at DESC").page(params[:page])
    thread_page_size = nil
    if current_user
      thread_page_size = current_user.current_presentation.threadpage_size
    end
    thread_page_size = Configurable[:default_homepage_threads] || Kaminari.config.default_per_page
    @threads = @threads.per(thread_page_size)
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
    not (Configurable[:recaptcha_public].blank? || Configurable[:recaptcha_private].blank?)
  end
  helper_method :captcha_enabled
  def captcha_ok?(opts = {})
    current_user || !captcha_enabled || verify_recaptcha({:model => @loginpost, :private_key => Configurable[:recaptcha_private]}.merge(opts))
  end
end
