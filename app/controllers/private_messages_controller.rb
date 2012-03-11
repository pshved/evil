class PrivateMessagesController < ApplicationController
  before_filter :new_private_message_from_params, :only => [:create]
  before_filter :new_private_message, :only => [:new]
  before_filter :find_private_message, :only => [:destroy,:update,:edit,:show]

  filter_access_to :create, :new, :show, :attribute_check => true
  filter_access_to :index, :attribute_check => false

  # GET /private_messages
  # GET /private_messages.json
  def index
    @private_messages = PrivateMessage.all_for(current_user).page(params[:page])
    # To show that the user has viewed these messages, mark them as read
    # We can't do this in a separate thread, because we should show that the messages are read at once
    @private_messages.where('unread').update_all 'unread = false'

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @private_messages }
    end
  end

  # GET /private_messages/1
  # GET /private_messages/1.json
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @private_message }
    end
  end

  # GET /private_messages/new
  # GET /private_messages/new.json
  def new
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @private_message }
    end
  end

  # You can't edit a private message once it's sent.
  #def edit
  #end

  # POST /private_messages
  # POST /private_messages.json
  def create
    if params[:commit] == 'Preview'
      @private_message.valid?
      respond_to do |format|
        flash[:notice] = 'This is a preview only!'
        format.html { render action: "new" }
      end
    else
      respond_to do |format|
        if @private_message.save
          format.html { redirect_to private_messages_path, notice: 'Private message was successfully created.' }
          format.json { render json: @private_message, status: :created, location: @private_message }
        else
          format.html { render action: "new" }
          format.json { render json: @private_message.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  private
  def find_private_message
    @private_message = PrivateMessage.find_by_stamp(params[:id])
  end

  def new_private_message_from_params
    @private_message = PrivateMessage.new(params[:private_message].merge(:current_user => current_user))
  end

  def new_private_message
    @private_message = PrivateMessage.new(:current_user => current_user, :recipient_user_login => params[:to], :reply_to_stamp => params[:replyto])
  end
end
