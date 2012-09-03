class PresentationsController < ApplicationController
  before_filter :new_presentation_from_params, :only => [:create]
  before_filter :new_presentation, :only => [:new]
  before_filter :find_presentation, :only => [:destroy,:update,:edit,:show,:clone,:use,:make_default]
  before_filter :find_presentations, :except => [:edit_local,:edit_default]

  filter_access_to :create, :new, :show, :attribute_check => true
  filter_access_to :clone, :require => :create, :attribute_check => true
  filter_access_to :use, :make_default, :require => :update, :attribute_check => true
  filter_access_to :index, :attribute_check => false
  filter_access_to :edit_default, :attribute_check => false

  before_filter :verify_get_csrf, :only => [:use, :clone, :make_default]

  before_filter :load_supplement, :only => [:new, :index, :edit, :update, :create]

  # GET /presentations
  # GET /presentations.json
  def index
    # Won't fail: prerequisite is a logged in user
    @presentation = current_user.current_presentation(cookies)
    # We redirect to editing the current presentation, and it will show the list of presentations
    redirect_to edit_presentation_path(current_presentation)
  end

  # GET /presentations/new
  # GET /presentations/new.json
  def new
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @presentation }
    end
  end

  def clone
    @presentation = @presentation.clone
    render :action => 'new'
  end

  # GET /presentations/1/edit
  def edit
  end

  # POST /presentations
  # POST /presentations.json
  # If current user is not set, then we're creating a local view
  def create
    respond_to do |format|
      if @presentation.save
        format.html { redirect_to edit_presentation_path(@presentation), notice: 'Presentation was successfully created.' }
        format.json { render json: @presentation, status: :created, location: @presentation }
      else
        format.html { render action: "new" }
        format.json { render json: @presentation.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /presentations/1
  # PUT /presentations/1.json
  def update
    respond_to do |format|
      if @presentation.update_attributes(params[:presentation])
        format.html { render action: :edit, notice: 'Presentation was successfully updated.' }
        format.json { head :ok }
      else
        format.html { render action: "edit" }
        format.json { render json: @presentation.errors, status: :unprocessable_entity }
      end
    end
  end

  def make_default
    if @presentation.make_default
      redirect_to :action => 'edit'
    else
      render :action => 'edit', :notice => "Couldn't set this view as default"
    end
  end

  # DELETE /presentations/1
  # DELETE /presentations/1.json
  def destroy
    @presentation.destroy

    respond_to do |format|
      format.html { redirect_to presentations_url }
      format.json { head :ok }
    end
  end

  def use
    # Update user's cookies
    @presentation.use(cookies)
    redirect_to :action => 'edit'
  end

  # This action does not require current_user!
  def edit_local
    if current_user
      redirect_to :action => 'index'
      return
    end
    @presentations = []
    # If the current presentation is global, then duplicate it
    @presentation = current_presentation(:never_global => true)
  end

  def edit_default
    @presentations = []
    @presentation = Presentation.default
  end

  private
  def find_presentation
    @presentation = Presentation.find(params[:id])
  end
  def find_presentations
    @presentations = current_user ? current_user.presentations : []
  end

  def new_presentation_from_params
    if current_user
      # Create presentation for the user (if it's not a global, site-wide, special presentation
      @presentation = Presentation.new(params[:presentation])
      @presentation.user = current_user if (params[:presentation][:global].blank? || (params[:presentation][:global] == '0'))
    else
      # Create local presentation
      @presentation = Presentation.new({:name => 'local'}.merge(params[:presentation])).record_into(cookies,request.remote_ip)
    end
  end

  def new_presentation
    @presentation = Presentation.new(:user => current_user)
  end

  def load_supplement
    @user = current_user
    @pazuzus = @user ? @user.pazuzus : []
    @hidden_posts = @user ? @user.hidden_posts : []
  end
end
