# TODO: why doesn't it work?
require 'autoload/post_validations'

class Loginpost
  include ActiveModel::Validations

  # Satisfy the form
  include ActiveModel::Conversion
  extend ActiveModel::Naming
  def persisted? ; false ; end

  # Input attrs
  attr_accessor :session, :autologin, :title, :body, :user
  # Autologin reader: it's a stupid checkbox
  def autologin
    not (@autologin.blank? || @autologin == '0')
  end

  # reply_to attr is a hidden field that contains the ID of the post you reply to to track this across validation failures
  # If it's nil then you're creating a new thread
  attr_accessor :reply_to

  # Additional attrs.
  extend PostValidators
  validates_post_attrs


  # Login validation re-uses session class with nested attributes
  def session_attributes=(atts)
    # Check the password to see if it's an unreg posting
    @unreg_posting = atts[:password].blank?
    # Create the session
    @session = UserSession.new(atts)
  end
  validate :valid_login

  # Check if the username and password are valid.  These are either valid credentials for a registred user, or a password-less
  def valid_login
    # If a user is already supplied, it's valid then
    return true if @user
    # Otherwise, read user's credentials from the form
    # If a passowrd is blank, then we're posting as an unreg
    if @unreg_posting
      if User.find_by_login(session.login)
        session.errors[:password] = "can not be blank, because #{session.login} is already registered"
        errors.add(:base, "Enter password!")
      end
    else
      if @session && @session.valid?
        @user = User.find_by_login(session.login)
      else
        errors.add(:base, "Invalid credentials")
      end
    end
  end

  # Log the user in if necessary (session is already validated)
  def log_in_if_necessary
    if !@unreg_posting && autologin
      session.save!
    end
  end

  # Returns the newly created post.  You should fill it with more information
  def post
    p = @saved_post.nil?? Posts.new(:title => title, :body => body) : @saved_post
    if @unreg_posting
      p.unreg_name = session.login
    else
      p.user = @user
    end
    @saved_post = p
  end
  # Saved post, for validation errors
  attr_accessor :saved_post

  def initialize(ats = {})
    ats.each do |k,v|
      send("#{k}=",v)
    end
    @session ||= UserSession.new
  end

  # This is a method that works like a regular save method, saving a post and checking if it is valid
  def save
    if valid?
      # since we're trying to save our post, we update the cached item, so that the form can read its errors
      @saved_post = post
      # Object to save (thread/post)
      to_save = @saved_post.attach_to(reply_to)
      to_save.save
    else
      false
    end
  end
end
