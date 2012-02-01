class PresentationsController < ApplicationController
  before_filter :new_presentation_from_params, :only => [:create]
  before_filter :new_presentation, :only => [:new]
  before_filter :find_presentation, :only => [:destroy,:update,:edit,:show]

  before_filter :set_default_page_size, :only => [:destroy,:update,:edit,:show,:new,:create]


  filter_access_to :create, :new, :show, :attribute_check => true
  filter_access_to :index, :attribute_check => false

  # GET /presentations
  # GET /presentations.json
  def index
    @presentations = current_user.presentations.order('created_at DESC').all
    case @presentations.length
    when 0
      redirect_to :action => 'new'
    when 1
      redirect_to edit_presentation_path(@presentations[0])
    else
      respond_to do |format|
        format.html # index.html.erb
        format.json { render json: @presentations }
      end
    end
  end

  # GET /presentations/new
  # GET /presentations/new.json
  def new
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @presentation }
    end
  end

  # GET /presentations/1/edit
  def edit
  end

  # POST /presentations
  # POST /presentations.json
  def create
    respond_to do |format|
      if @presentation.save
        format.html { redirect_to @presentation, notice: 'Presentation was successfully created.' }
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

  # DELETE /presentations/1
  # DELETE /presentations/1.json
  def destroy
    @presentation.destroy

    respond_to do |format|
      format.html { redirect_to presentations_url }
      format.json { head :ok }
    end
  end

  private
  def find_presentation
    @presentation = Presentation.find(params[:id])
  end

  def new_presentation_from_params
    @presentation = Presentation.new(params[:presentation].merge(:current_user => current_user))
  end

  def new_presentation
    @presentation = Presentation.new(:current_user => current_user)
  end

  def set_default_page_size
    @presentation.threadpage_size = Kaminari.config.default_per_page if @presentation.threadpage_size.blank?
  end
end
