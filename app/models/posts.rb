# TODO: why doesn't it autoload??
require 'autoload/post_validations'
require 'markup/boardtags'

class Posts < ActiveRecord::Base
  belongs_to :user
  belongs_to :text_container, :autosave => true
  # touch attr updates the thread's timestamp if its post is updated
  # We need class_name since Thread is a system class
  belongs_to :thread, :touch => true, :class_name => 'Threads'
  belongs_to :parent, :class_name => 'Posts', :inverse_of => :children
  has_many :children, :class_name => 'Posts', :foreign_key => 'parent_id'

  has_one :click, :foreign_key => 'post_id'

  validates_presence_of :thread, :strict => true
  # Each post should have a parent except for the root ones
  # I had to rename "empty?" method and "empty" field on Posts to "empty_body", as it treated a post with an empty body as blank, and invalidated its kid
  validates_presence_of :parent, :if => proc { |p| p.thread && (p.thread.head != p) }, :strict => true
  # Just checking...
  validates_presence_of :text_container, :strict => true

  # Check that there's no two imported posts with the same ID (not strict because we may want to return a value to an importer)
  validates_uniqueness_of :back, :unless => proc {|p| p.back.blank?}

  # Other validations
  extend PostValidators
  validates_post_attrs

  # String statuses for enum/str db crunching
  ST_OPEN = 'open'
  ST_CLOSED = 'closed'

  # Post's marks
  # They are stored as a serialized array
  # NOTE: since there are millions of posts, and only a few combinations of marks, we might want to use caching for deserialized values. I'm not sure if it's documented, but we can specify a loader object here instead of the object's class name.   As a side effect, returns FROZEN records!
  serialize :marks, FasterPost::CachingYaml.new
  # However, if they are unset, we should show the user an array
  def marks
    read_attribute(:marks) || []
  end
  # a hook that updates marks (after the post has been edited or created)
  before_save :renew_marks
  before_save :renew_emptiness
  class PostParseContext < DefaultParseContext
  end
  def renew_marks
    context = PostParseContext.new
    # Call the parser
    text_container.filtered(context)[1]
    # Read the context and update marks
    self.marks = context.sign.keys.map(&:to_s).sort
    true
  end

  # Update whether the post is empty (needed for optimization)
  def renew_emptiness
    self.empty_body = body.strip.blank?
    true
  end

  # This should NOT be called "empty?", as it interferes with validates_presence_of!
  def empty_body?
    empty_body
  end


  # Post fields accessors
  # All textual fields are stored in the text container.  We should create one before accessing them
  private
  def ensure_container
    self.text_container ||= TextContainer.make('','') # Smile! ^_^
    self.text_container
  end
  public

  def title
    ensure_container.body[0]
  end

  def body
    ensure_container.body[1]
  end

  # Post's body after the proper filter application
  def filtered_body
    text_container.filtered[1]
  end

  # Attach post to the proper thread (or create a new one).  Return the object to save (either a thread or this post)
  def attach_to(reply_to)
    if reply_to.blank?
      # A new thread
      thr = Threads.create
      thr.head = self
      self.thread = thr
      # Thread will automatically save and validate the post, so return it
      thr
    else
      logger.info "RPLTO >>> Replying to #{reply_to}"
      rp = Posts.find(reply_to)
      self.thread = rp.thread
      self.parent = rp
      self
    end
  end

  # Check if the post was hidden by the current user
  def hidden_by?(opts = {})
    user = opts[:user]
    thread_hides = opts[:thread_hides] || {}
    hidden = false
    # User's own settings override all
    if user
      hidden ||= user.hidden_posts.exists?(self.id)
    end
    # Now moderator's settings follow
    # TODO
    # Now thread's auto-folding works (site-wide threshold)
    hidden ||= (!opts[:show_all] && thread_hides[self.id])
    hidden
  end
  def toggle_showhide(user)
    if hidden_by?(:user => user)
      user.hidden_posts.delete self
    else
      user.hidden_posts << self
    end
  end

  # Editing posts and revisions
  def title=(title)
    ensure_container[0] = title
  end

  def body=(body)
    ensure_container[1] = body
  end

  before_validation do
    ensure_container
    true
  end

  # Belongs_to associations, unlike has_one, need to be saved explicitly
  before_save do
    text_container.save
  end

  def click!(user = nil, rq = '127.0.0.1')
    # If post has not been clicked, assume that the previous clicker was the authos
    build_click(:last_click => Click.clicker(self.user,rq)) unless click
    click.click! user,rq
  end

  def clicks
    click ? (click.clicks || 0) : 0
  end

  # Post parent helper (used as a generic interface between Post and FasterPost)
  def parent_value
    parent.nil?? nil : parent.id
  end

  def user_login
    user.nil??  nil : user.login
  end

end
