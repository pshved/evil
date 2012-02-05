class PostsController < ApplicationController
  before_filter :find_post, :only => [:edit, :update, :show, :destroy, :toggle_showhide]
  before_filter :find_thread, :only => [:edit, :update, :show]
  before_filter :init_loginpost, :only => [:edit, :update]

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
    @post.maybe_new_revision_for_edit

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
    redirect_to :back
  end

  protected
  def find_post
    @post = Posts.find(params[:id])
  end
  def find_thread
    @thread = @post.thread
  end
  def init_loginpost
  end
end
