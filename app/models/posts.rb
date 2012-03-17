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

  # Do NOT auto-save clicks!  We do not caches to be invalidated constantly.
  has_one :click, :foreign_key => 'post_id'

  validates_presence_of :thread, :strict => true
  # Each post should have a parent except for the root ones
  # I had to rename "empty?" method and "empty" field on Posts to "empty_body", as it treated a post with an empty body as blank, and invalidated its kid
  validates_presence_of :parent, :if => proc { |p| p.thread && (p.thread.head != p) }, :strict => true
  # Just checking...
  validates_presence_of :text_container, :strict => true

  # Check that there's no two imported posts with the same ID (not strict because we may want to return a value to an importer)
  validates_uniqueness_of :back, :unless => proc {|p| p.back.blank?}

  # This checks that you are not replying to a closed thread, or to a deleted post
  validate :replies_to_open?

  # Check if the username and password are valid.  These are either valid credentials for a registred user, or a password-less
  def replies_to_open?
    if parent && parent.deleted
      errors.add(:base, "You can't reply to a deleted post!")
    end
  end

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
  def self.hidden_by?(id, userhide_action, opts = {})
    # If we're in the single-post view, just show everything
    return false if opts[:show_all]
    # Otherwise, take into account the following: user's hides, thread auto-hides
    post_info = (opts[:thread_info] || {})[id] || {}
    hidden = false
    # User's own settings override all
    return HiddenPostsUsers.need_hide(userhide_action) if userhide_action
    # Now moderator's settings follow
    # TODO
    # Now thread's auto-folding works (site-wide threshold)
    hidden ||= post_info[:hidden]
    hidden
  end
  def hidden_by?(opts = {})
    userhide = nil
    if opts[:user] && (uha = opts[:user].hide_actions.where(['posts_id = ?',self.id]).first)
      userhide = uha.action
    end
    Posts.hidden_by?(id,userhide,opts)
  end
  def toggle_showhide(user,presentation)
    # We should check if the user hides the thread with his or her settings
    # TODO refactor thread queries
    Threads.settings_for = user
    pthr = thread
    pthr.presentation = presentation
    #
    hidden = hidden_by?(:user => user, :thread_info => pthr.hides_fast)
    if hide_assoc = user.hide_actions.where(['posts_id = ?',self.id]).first
      # Alter the hide association
      hide_assoc.action = HiddenPostsUsers.inverse_hidden(hidden)
      hide_assoc.save
    else
      HiddenPostsUsers.create(:user_id => user.id, :posts_id => self.id, :action => HiddenPostsUsers.inverse_hidden(hidden))
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
    # If post has not been clicked, assume that the previous clicker was the author
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

  # This procedure recursively removes the kids of the post, but doesn't remove the post itself.
  def hide_kids(moderator,reason)
    this_thread = self.thread.build_subtree_fast
    # Get the IDs of the whole subtree
    queue = [self.id]
    to_remove = []
    while not queue.empty?
      puts "ITER: #{queue.inspect} --- #{to_remove.inspect}"
      last = queue.shift
      to_remove << last
      queue += (this_thread[last] || []).map(&:id)
    end
    # The first item of to_remove array is our post which we shouldn't remove.
    to_remove.shift
    # Now remove them with a single SQL
    ActiveRecord::Base.connection.execute(%Q{UPDATE posts SET deleted = true WHERE id in (#{to_remove.join(',')})})
    # And insert moderation comments
    to_remove.each do |rm_id|
      ModerationAction.create(:post_id => rm_id, :user => moderator, :reason => reason)
    end
  end

  # This is not the same as updated_at... when a post is shown/hidden by a user, its update mark is changed.  We should refactor it later.
  def edited_at
    text_container ? text_container.updated_at : updated_at
  end

end
