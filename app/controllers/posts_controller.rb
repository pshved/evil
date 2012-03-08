class PostsController < ApplicationController
  before_filter :find_post, :only => [:edit, :update, :show, :destroy, :toggle_showhide, :remove]
  before_filter :find_thread, :only => [:edit, :update, :show, :remove]
  before_filter :init_loginpost, :only => [:edit, :update]

  # Trick authorization by supplying a "fake" @posts to make it skip loagind the object
  before_filter :trick_authorization, :only => [:latest]
  filter_access_to :all, :attribute_check => true, :model => Posts

  # GET /posts/1
  # GET /posts/1.json
  def show
    @loginpost = Loginpost.new(:reply_to => @post.to_param, :user => current_user)
    # To ignore show/hide settings and always show.
    @show_all_posts = true
    # Add click
    @post.click! current_user, request.remote_ip
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @post }
    end
  end

  # GET /posts/new
  # GET /posts/new.json
  def new
    @post = Posts.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @post }
    end
  end

  # GET /posts/1/edit
  def edit
  end

  # POST /posts
  # POST /posts.json
  def create
    @post = Posts.new(params[:post])

    respond_to do |format|
      if @post.save
        format.html { redirect_to @post, notice: 'Post was successfully created.' }
        format.json { render json: @post, status: :created, location: @post }
      else
        format.html { render action: "new" }
        format.json { render json: @post.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /posts/1
  # PUT /posts/1.json
  def update
    if params[:commit] == 'Preview'
      @post.assign_attributes(params[:posts])
      # This is a preview, validate and show it
      @post.valid?
      respond_to do |format|
        flash[:notice] = 'This is a preview only!'
        format.html { render action: "edit" }
      end
    else
      respond_to do |format|
        if @post.update_attributes(params[:posts])
          format.html { redirect_to @post, notice: 'Posts was successfully updated.' }
          format.json { head :ok }
        else
          format.html { render action: "edit" }
          format.json { render json: @post.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  # DELETE /posts/1
  # DELETE /posts/1.json
  def destroy
    @post.destroy

    respond_to do |format|
      format.html { redirect_to posts_url }
      format.json { head :ok }
    end
  end

  def toggle_showhide
    @post.toggle_showhide(current_user)
    @post.save
    # TODO: add Ajax here.  For now, redirects back.
    begin
      redirect_to :back
    rescue ActionController::RedirectBackError
      redirect_to @post
    end
  end

  def latest
    # Get threads for the latest
    length = params[:number].blank? ? POST_FEED_LENGTH : params[:number].to_i
    # This fetches bodies as well, but they're rendered only at the view
    @posts = FasterPost.latest(length,current_user,permitted_to?(:see_deleted,:posts))

    respond_to do |format|
      format.html # latest.html.erb
      format.rss { render :layout => false }
    end
  end

  # This action doesn't permanently remove the post from database.  It hides the post, so that it can be only viewed by very few users.
  # This action will be used by moderators to remove posts and spam.
  def remove
    # Remove post, and if it was an only post in a thread, remove the thread as well.
    # The post and the thread have already been found in the filters
    @post.deleted = true
    # NOTE that the thread will be updated at the @post.save due to a wisely specified :autosave attribute at association, and the caches will be rebuilt.
    if @post.save
      # The post was deleted, add a record to the moderation log
      ModerationAction.create(:post => @post, :user => current_user, :reason => 'Remove SPAM')
      # This post may have children.  Remove them as well in a separate thread.
      spawn do
        @post.hide_kids(current_user,"Belongs to subthread of a removed #{post_url(@post)} due to Remove SPAM!")
      end
      respond_to do |format|
        format.html { redirect_to @post, notice: "The post and its subthread has been removed.  Regular users will not see it." }
      end
    else
      respond_to do |format|
        format.html { render action: "edit", notice: "Can't delete post; try to edit it?" }
      end
    end
  end

  protected
  def find_post
    @post = Posts.find(params[:id])
  end
  def find_thread
    Threads.settings_for = current_user
    @thread = @post.thread
    @thread.presentation = current_presentation
  end
  def init_loginpost
  end
  @@fake_posts = nil
  def trick_authorization
    @posts = @@fake_posts if @@fake_posts
    @posts = @@fake_posts = Posts.find(:first)
  end
end
