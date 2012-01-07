# TODO: why doesn't it work?
require 'autoload/post_validations'

class Loginpost
  include ActiveModel::Validations

  # Satisfy the form
  include ActiveModel::Conversion
  extend ActiveModel::Naming
  def persisted? ; false ; end

  # Input attrs
  attr_accessor :login, :password, :autologin, :title, :body

  # reply_to attr is a hidden field that contains the ID of the post you reply to to track this across validation failures
  # If it's nil then you're creating a new thread
  attr_accessor :reply_to

  # Additional attrs.
  extend PostValidators
  validates_post_attrs

  validate :valid_login

  # Check if the username and password are valid.  These are either valid credentials for a registred user, or a password-less
  def valid_login
    # TODO: stub!
    # This should set up @user or @unreg_name
    true
  end

  # Returns the newly created post.  You should fill it with more information
  def post
    p = Posts.new
    if @user
      p.user = @user
    else
      p.unreg_name = @unreg_name
    end
    p.text_container = TextContainer.make(title,body)
    p
  end
  # Saved post, for validation errors
  attr_accessor :saved_post

	def initialize(ats = {})
		ats.each do |k,v|
			send("#{k}=",v)
		end
	end

  # This is a method that works like a regular save method, saving a post and checking if it is valid
  def save
    if valid?
      # since we're trying to save our post, we update the cached item, so that the form can read its errors
      @saved_post = post
      # Check if we're creating a new thread
      if reply_to.blank?
        # A new thread
        thr = Threads.create
        thr.head = @saved_post
        @saved_post.thread = thr
        # Thread will automatically save and validate the post
        thr.save && @saved_post
      else
        rp = Posts.find(reply_to)
        @saved_post.thread = rp.thread
        @saved_post.parent = rp
        @saved_post.save
      end
    else
      false
    end
  end
end
