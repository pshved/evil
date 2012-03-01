class PostsController < ApplicationController
  before_filter :find_post, :only => [:edit, :update, :show, :destroy, :toggle_showhide]
  before_filter :find_thread, :only => [:edit, :update, :show]
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
    # TODO: make it DRY with Threads model!
    settings_for = current_user
    length = params[:number].blank? ? POST_FEED_LENGTH : params[:number].to_i
    # This fetches bodies as well, but they're rendered only at the view
    @posts = FasterPost.find_by_sql(["select posts.id, text_items.body as title, posts.created_at, posts.empty_body, posts.parent_id, posts.marks, posts.unreg_name, users.login as user_login, posts.host, clicks.clicks, hidden_posts_users.posts_id as hidden, body_items.body as body, text_containers.filter as body_filter
    from posts
    join text_containers on posts.text_container_id = text_containers.id
    join text_items on (text_items.text_container_id = text_containers.id) and (text_items.revision = text_containers.current_revision)
    join text_items as body_items on (body_items.text_container_id = text_containers.id) and (body_items.revision = text_containers.current_revision)
    left join users on posts.user_id = users.id
    left join clicks on clicks.post_id = posts.id
    left join hidden_posts_users on hidden_posts_users.user_id = #{settings_for ? settings_for.id : 'NULL'} and hidden_posts_users.posts_id = posts.id
    where text_items.number = 0 and body_items.number = 1
    order by posts.created_at desc limit ?", length])

    respond_to do |format|
      format.html # latest.html.erb
      format.rss { render :layout => false }
    end
  end

  protected
  def find_post
    @post = Posts.find(params[:id])
  end
  def find_thread
    Threads.settings_for = current_user
    @thread = @post.thread
  end
  def init_loginpost
  end
  @@fake_posts = nil
  def trick_authorization
    @posts = @@fake_posts if @@fake_posts
    @posts = @@fake_posts = Posts.find(1)
  end
end
