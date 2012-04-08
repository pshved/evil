class PostsController < ApplicationController
  caches_action :show, :unless => proc {current_user}, :cache_path => proc {"post_#{params[:id]}"},
    :expires_in => UNREG_VIEW_CACHE_TIME, :race_condition_ttl => UNREG_VIEW_CACHE_UPDATE_TIME

  before_filter :find_post, :only => [:edit, :update, :show, :destroy, :toggle_showhide, :remove]
  before_filter :find_thread, :only => [:edit, :update, :show, :remove]
  before_filter :init_loginpost, :only => [:edit, :update]

  # Record post click (doing this in before_filter for it to work even if the page is cached)
  before_filter :click, :only => [:show]

  # Trick authorization by supplying a "fake" @posts to make it skip loagind the object
  before_filter :trick_authorization, :only => [:latest]
  filter_access_to :all, :attribute_check => true, :model => Posts

  before_filter :invalidate_index_pages, :only => [:update, :toggle_showhide, :remove]

  # GET /posts/1
  # GET /posts/1.json
  def show
    @loginpost = Loginpost.new(:reply_to => @post.to_param, :user => current_user)
    # To ignore show/hide settings and always show.
    @show_all_posts = true
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
    if params[:commit] == 'Preview'
      @post.assign_attributes(params[:posts])
      # This is a preview, validate and show it
      @post.valid?
      respond_to do |format|
        flash[:notice] = t('notice.preview')
        format.html { render action: "edit" }
      end
    else
      respond_to do |format|
        if @post.update_attributes(params[:posts])
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
    @post.save
    # TODO: add Ajax here.  For now, redirects to the post at the index page
    redirect_to root_path(:anchor => @post.id)
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

  def click
    post_clicks_tracker.event(@post.id)
  end
end
