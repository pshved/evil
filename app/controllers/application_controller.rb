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
  # TODO: account for user's settings and paginationn
  def prepare_threads
    # TODO: stub
    @threads = Threads.order("created_at DESC").page(params[:page]).per(2)
    # We do not set up parent, so the login post is new.
    @loginpost = Loginpost.new(:user => current_user)
  end
end
