class UsersController < ApplicationController
  before_filter :find_user, :only => [:show, :update, :edit, :destroy]

  filter_resource_access

  # GET /users
  # GET /users.json
  def index
    @users = User.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @users }
    end
  end

  # GET /users/1
  # GET /users/1.json
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @user }
    end
  end

  # GET /users/new
  # GET /users/new.json
  def new
    @user = User.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @user }
    end
  end

  # GET /users/1/edit
  def edit
  end

  # POST /users
  # POST /users.json
  def create
    @user = User.new(params[:user])

    respond_to do |format|
      if captcha_ok?(:model => @user) && @user.save
        flash[:notice] = 'Registration successful'
        format.html { redirect_to @user, notice: 'User was successfully created.' }
        format.json { render json: @user, status: :created, location: @user }
      else
        format.html { render action: "new" }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /users/1
  # PUT /users/1.json
  def update
    respond_to do |format|
      if @user.demo
        format.html { redirect_to @user, notice: %Q(You can not edit a demonstration user's settings) }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      elsif @user.update_attributes(params[:user])
        format.html { redirect_to @user, notice: 'User was successfully updated.' }
        format.json { head :ok }
      else
        @user.current_password = nil
        format.html { render action: "edit" }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /users/1
  # DELETE /users/1.json
  def destroy
    @user.destroy

    respond_to do |format|
      format.html { redirect_to users_url }
      format.json { head :ok }
    end
  end

  protected
  def find_user
    # We do not use 'self' to avoid problems with declarative auth
    @user = User.from_param(params[:id])
  end
  # Alias for filter_resource_access: it expects "load_user" method rather than find_user.
  alias_method :load_user, :find_user
end
