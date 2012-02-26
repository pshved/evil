class PresentationsController < ApplicationController
  before_filter :new_presentation_from_params, :only => [:create]
  before_filter :new_presentation, :only => [:new]
  before_filter :find_presentation, :only => [:destroy,:update,:edit,:show,:clone,:use,:make_default]
  before_filter :find_presentations

  filter_access_to :create, :new, :show, :attribute_check => true
  filter_access_to :clone, :require => :create, :attribute_check => true
  filter_access_to :use, :make_default, :require => :update, :attribute_check => true
  filter_access_to :index, :attribute_check => false

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

  private
  def find_presentation
    @presentation = Presentation.find(params[:id])
  end
  def find_presentations
    # Won't fail: prerequisite is a logged in user
    @presentations = current_user.presentations
  end

  def new_presentation_from_params
    @presentation = Presentation.new(params[:presentation].merge(:user => current_user))
  end

  def new_presentation
    @presentation = Presentation.new(:user => current_user)
  end
end
