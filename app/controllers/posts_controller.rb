class PostsController < ApplicationController
  # Record post click (doing this in before_filter for it to work even if the page is cached)
  before_filter :click, :only => [:show]

  caches_action :show, :unless => proc {current_user}, :cache_path => proc {"post_#{params[:id]}"},
    :expires_in => UNREG_VIEW_CACHE_TIME, :race_condition_ttl => UNREG_VIEW_CACHE_UPDATE_TIME

  before_filter :find_post, :only => [:edit, :update, :show, :destroy, :toggle_showhide, :remove, :toggle_like]
  before_filter :find_thread, :only => [:edit, :update, :show, :remove, :toggle_showhide, :toggle_like]
  before_filter :init_loginpost, :only => [:edit, :update]

  # Trick authorization by supplying a "fake" @posts to make it skip loagind the object
  before_filter :trick_authorization, :only => [:latest]
  filter_access_to :all, :attribute_check => true, :model => Posts

  before_filter :invalidate_index_pages, :only => [:update, :toggle_showhide, :remove]

  # Find the source so that a user can post there
  before_filter :initialize_source, :only => [:show]

  # GET /posts/1
  # GET /posts/1.json
  def show
    @loginpost = Loginpost.new(:reply_to => @post.to_param, :user => current_user)
    # To ignore show/hide settings and always show.
    @show_all_posts = true
    respond_to do |format|
      format.html # show.html.erb
      # For now, this only shows body; perhaps, the behavior will be changed in the future!
      format.json { render :json => {'body' => @post.filtered_body, 'id' => @post.id} }
      #format.js
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
        format.html { redirect_to @post, notice: t('notice.posted') }
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
    if ! params[:preview].blank?
      @post.assign_attributes(params[:posts])
      # This is a preview, validate and show it
      @post.valid?
      respond_to do |format|
        flash[:notice] = t('notice.preview')
        format.html { render action: "edit" }
      end
    else
      respond_to do |format|
        # Set the editor for the post
        @post.assign_attributes(params[:posts])
        @post.last_editor = current_user
        if @post.save
          format.html { redirect_to @post, notice: t('notice.edited') }
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
    @post.toggle_showhide(current_user,current_presentation)
    @post.touch
    # NOTE: This has loaded post's thread (since hides may be induced by thread structure).  We should reload post if we're going to render it at _this_ request.
    respond_to do |format|
      format.html { redirect_to root_path(:anchor => @post.id) }
      format.js do
        # Toggling showhide changed thread structure; reload
        find_post
        find_thread
        # now render
      end
    end
  end

  def toggle_like
    @post.toggle_like(current_user)
    # Do heavier update than just touch.
    @post.quick_update_likes
    # NOTE: This has loaded post's thread (since hides may be induced by thread structure).  We should reload post if we're going to render it at _this_ request.
    respond_to do |format|
      format.html { redirect_to root_path(:anchor => @post.id) }
      format.js do
        # Toggling showhide changed thread structure; reload
        find_post
        find_thread
        # now render
      end
    end
  end

  def latest
    # Get threads for the latest
    length = params[:number].blank? ? POST_FEED_LENGTH : params[:number].to_i
    # This fetches bodies as well, but they're rendered only at the view
    # RSS needs bodies, so fetch them in this case as well
    @posts = FasterPost.latest(length,current_user,permitted_to?(:see_deleted,:posts))

    respond_to do |format|
      format.html { @posts = FasterPost.latest(length,current_user,permitted_to?(:see_deleted,:posts)) }
      format.rss do
        @posts = FasterPost.latest(length,current_user,permitted_to?(:see_deleted,:posts),true)
        render :layout => false
      end
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
        format.html { redirect_to @post, notice: t('notice.moderation.removed') }
      end
    else
      respond_to do |format|
        format.html { render action: "edit", notice: t('notice.moderation.cantedit') }
      end
    end
  end

  protected
  def find_post
    @post = Posts.find(params[:id])
  end
  def find_thread
    @thread = @post.thread
    @thread.presentation = current_presentation
    @thread.settings_for = current_user
    # HACK HACK HACK!  Move this to presentation-like layer!
    if current_user
      @thread.settings_for.nopazuzu = !params[:nopazuzu].blank?
      @thread.presentation.updated_at = Time.now if !params[:nopazuzu].blank?
    end
    # END of hack
  end
  def init_loginpost
  end
  @@fake_posts = nil
  def trick_authorization
    @posts = @@fake_posts if @@fake_posts
    @posts = @@fake_posts = Posts.find(:first)
  end

  def click
    # Don't try to find the post: just record the access!
    post_clicks_tracker.event(params[:id])
  end

  def initialize_source
    return unless @post && @post.import && (source = @post.import.source)
    # We show source reply by default
    if source && params[:source].blank?
      @import = @post.import
      @source = source
      # For now, only replies are supported.
      @source_reply_to = @post.import.back
    else
      # source name mismatch, retry
      @source = nil
    end


  end
end
