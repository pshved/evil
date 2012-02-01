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

  validates_presence_of :thread
  # Each post should have a parent except for the root ones
  validates_presence_of :parent, :if => proc { |p| p.thread && (p.thread.head != p) }
  # Just checking...
  validates_presence_of :text_container

  # Check that there's no two imported posts with the same ID
  validates_uniqueness_of :back, :unless => proc {|p| p.back.blank?}

  # Other validations
  extend PostValidators
  validates_post_attrs

  # String statuses for enum/str db crunching
  ST_OPEN = 'open'
  ST_CLOSED = 'closed'

  # Post's marks
  # They are stored as a serialized array
  serialize :marks
  # However, if they are unset, we should show the user an array
  def marks
    read_attribute(:marks) || []
  end
  # a hook that updates marks (after the post has been edited or created)
  before_save :renew_marks
  class PostParseContext < DefaultParseContext
  end
  def renew_marks
    context = PostParseContext.new
    # Call the parser
    debugger
    text_container.filtered(context)[1]
    # Read the context and update marks
    self.marks = context.sign.keys.map(&:to_s).sort
  end

  def title
    text_container.body[0]
  end

  def body
    text_container.body[1]
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
  def hidden_by?(user = nil)
    # TODO: merge moderator's hiding settings here
    hidden = false
    if user
      hidden ||= user.hidden_posts.exists?(self.id)
    end
    hidden
  end
  def toggle_showhide(user)
    if hidden_by?(user)
      user.hidden_posts.delete self
    else
      user.hidden_posts << self
    end
  end

end
