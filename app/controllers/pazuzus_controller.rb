class PazuzusController < ApplicationController
  before_filter :find_user
  before_filter :new_pazuzu_from_params, :only => [:create]
  before_filter :new_pazuzu, :only => [:new]
  before_filter :find_pazuzu, :only => [:destroy,:update,:edit,:show,:clone,:use,:make_default]
  before_filter :find_pazuzus, :except => [:edit_local,:edit_default]

  filter_access_to :create, :new, :show, :delete, :attribute_check => true
  filter_access_to :index, :attribute_check => false

  before_filter :checkboxes_for_pazuzu, :only => [:new, :edit]

  # GET /pazuzus
  # GET /pazuzus.json
  def index
    @pazuzus = Pazuzu.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @pazuzus }
    end
  end

  # GET /pazuzus/1
  # GET /pazuzus/1.json
  def show
    @pazuzu = Pazuzu.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @pazuzu }
    end
  end

  # GET /pazuzus/new
  # GET /pazuzus/new.json
  def new
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @pazuzu }
    end
  end

  # GET /pazuzus/1/edit
  def edit
  end

  # POST /pazuzus
  # POST /pazuzus.json
  def create
    respond_to do |format|
      if @pazuzu.save
        format.html { redirect_to edit_user_pazuzu_path(@user, @pazuzu), notice: t('notice.pazuzu.created') }
        format.json { render json: @pazuzu, status: :created, location: @pazuzu }
      else
        format.html { render action: "new" }
        format.json { render json: @pazuzu.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /pazuzus/1
  # PUT /pazuzus/1.json
  def update
    @pazuzu = Pazuzu.find(params[:id])

    respond_to do |format|
      if @pazuzu.update_attributes(params[:pazuzu])
        format.html { redirect_to user_pazuzus_url(@user), notice: t('notice.pazuzu.edited') }
        format.json { head :ok }
      else
        format.html { render action: "edit" }
        format.json { render json: @pazuzu.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /pazuzus/1
  # DELETE /pazuzus/1.json
  def destroy
    @pazuzu.destroy

    respond_to do |format|
      format.html { redirect_to user_pazuzus_url(@user) }
      format.json { head :ok }
    end
  end

  private
  def find_pazuzu
    @pazuzu = Pazuzu.find(params[:id])
  end
  def find_pazuzus
    @pazuzus = current_user ? current_user.pazuzus : []
  end

  def new_pazuzu_from_params
    if current_user
      @pazuzu = Pazuzu.new(params[:pazuzu])
      @pazuzu.user = current_user
    end
  end

  def new_pazuzu
    @pazuzu = Pazuzu.new({:user => current_user, :bastard_name => params['bastard'], :host => params['post_host'], :unreg_name => params['unreg_name']}, :without_protection => true)
  end

  def checkboxes_for_pazuzu
    @pazuzu.init_use if @pazuzu
  end

  def find_user
    @user = current_user
  end
end
