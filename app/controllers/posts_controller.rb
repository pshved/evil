class PostsController < ApplicationController
  before_filter :find_post, :only => [:edit, :update, :show, :destroy]
  before_filter :find_thread, :only => [:edit, :update, :show]
  before_filter :init_loginpost, :only => [:edit, :update, :show]

  # GET /posts/1
  # GET /posts/1.json
  def show

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

    respond_to do |format|
      if @post.update_attributes(params[:post])
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

  protected
  def find_post
    @post = Posts.find(params[:id])
  end
  def find_thread
    @thread = @post.thread
  end
  def init_loginpost
    @loginpost = Loginpost.new
    @loginpost.reply_to = @post.to_param
  end
end
