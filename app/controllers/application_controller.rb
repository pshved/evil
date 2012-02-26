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

  def current_presentation
    if current_user
      current_user.current_presentation(cookies)
    else
      return @default_presentation if @default_presentation
      @default_presentation = Presentation.default
    end
    # TODO: record access time, so that this presentation is not discarded
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
