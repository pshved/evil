class UserSessionsController < ApplicationController
  # CSRF protection: since logoff is a GET request, while it should be POST, we should authenticate a request via GET params, not just via cookies.
  # Reuse persistence token for this.  See ApplicationController for the method.
  before_filter :verify_get_csrf, :only => :destroy

  # GET /user_sessions
  # GET /user_sessions.json
  def index
    @user_sessions = UserSession.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @user_sessions }
    end
  end

  # GET /user_sessions/new
  # GET /user_sessions/new.json
  def new
    @user_session = UserSession.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @user_session }
    end
  end
 
  # POST /user_sessions
  # POST /user_sessions.json
  def create
    @user_session = UserSession.new(params[:user_session])

    respond_to do |format|
      if @user_session.save
        # If user has logged in, and there was a cookie-stored session, copy it to the user's
        if local_view = Presentation.from_cookies(cookies)
          # We do not "dup" this view to never see it again as an unreg.  This prevents polluting accounts with views if you login frequently, and were unlucky to modify user settings.
          # NOTE that current_user does NOT work here!  We have just saved the session, and "current_user" returns the previous userr!
          local_view.attach_to(@user_session.user)
        end
        format.html { redirect_to root_url, notice: t('notice.session.login') }
        format.json { render json: @user_session, status: :created, location: @user_session }
      else
        format.html { render action: "new" }
        format.json { render json: @user_session.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /user_sessions/1
  # DELETE /user_sessions/1.json
  def destroy
    @user_session = UserSession.find(params[:id])
    @user_session.destroy

    flash[:notice] = t('notice.session.logout')
    respond_to do |format|
      format.html { redirect_to root_url }
      format.json { head :ok }
    end
  end
end
