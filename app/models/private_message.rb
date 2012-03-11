# TODO: fix autoloader
require 'autoload/utils'

class PrivateMessage < ActiveRecord::Base
  belongs_to :sender_user, :class_name => 'User'
  belongs_to :recipient_user, :class_name => 'User'
  belongs_to :text_container, :autosave => true
  belongs_to :reply_to, :class_name => 'PrivateMessage'
  # Owner of the message (sender or receiver)
  belongs_to :user
  has_many :replies, :foreign_key => 'reply_to_id', :class_name => 'PrivateMessage'

  validates_presence_of :text_container
  validates_presence_of :sender_user
  # The message owner must exist
  validates_presence_of :user, :strict => true
  ## Instead of recipient_user, we validate its login
  #validates_presence_of :recipient_user
  # Body should not be empty
  validates_length_of :body, :in => 1..500, :allow_blank => false

  # Form validation
  attr_accessor :recipient_user_login, :msg_body, :current_user, :reply_to_stamp

  # For use in form
  validates_each :recipient_user_login, :on => :create do |record, attr, value|
    record.errors.add attr, 'does not exist' unless User.find_by_login(value)
  end

  # A persistent model doesn't need to repeat these initializations
  before_validation :on => :create do
    # Sender user may be already set by an explicit "create" call
    self.sender_user ||= self.current_user
    self.user ||= self.current_user
    self.recipient_user = User.find_by_login(recipient_user_login)
    self.text_container = TextContainer.make(msg_body)
    # No validation: will be nil if specified incorrectly (malice?)
    self.reply_to = reply_to_stamp.blank?? nil : PrivateMessage.find_by_stamp(reply_to_stamp)
    true
  end

  # After a private message was successfully created, create and save a paired message.
  # To avoid recursion, the new message is guarded with a :skip_counterpart flag
  attr_accessor :skip_counterpart
  def save_dupe
    # We do not know if the message was loaded from a database or has just been created.  In both cases, parameters that originate from the db are available at this point, so let's use them.
    PrivateMessage.create({
      :skip_counterpart => true,
      :current_user => recipient_user,
      :sender_user => sender_user,
      :recipient_user_login => recipient_user.login,
      :msg_body => body,
      :reply_to_stamp => (reply_to ? reply_to.stamp : nil),
      :created_at => created_at})
  end
  after_create do
    unless skip_counterpart
      save_dupe
    end
  end

  # Call this method to convert messages from the old format (one message per two users)
  def create_duplicate
    self.user ||= sender_user
    save && save_dupe
  end

  # Return query template for all messages sent to/received by a given user.  You should finalize the query by applying .all or something like this to the returned object.
  def self.all_for(user)
    return [] if user.nil?
    user.private_messages.order('created_at DESC')
  end

  # Message referencing
  def to_param
    stamp
  end

  before_create :generate_stamp
  def generate_stamp
    begin
      stamp = "pm#{generate_random_string( (Math.log(PrivateMessage.count + 1)/Math.log(10)).to_int + 4,  '0123456789')}"
    end until not PrivateMessage.find_by_stamp(stamp)
    self.stamp = stamp
  end
  validates_uniqueness_of :stamp, :scope => :user_id
  def find_by_stamp(s)
    PrivateMessage.find_first_by_stamp(s)
  end

  def body
    text_container ? text_container.body[0] : msg_body
  end
  def filtered_body
    text_container ? text_container.filtered[0] : msg_body
  end

  # Returns a list of users (IDs of them) that may view the message this one replies to.  If it's not a reply, return current user.  If a message to be replied to is not found, then someone's tampering with replies, and we return nobody.
  def viewable_by
    # TODO : DRY!
    is_a_reply = self.reply_to || !reply_to_stamp.blank?
    return [current_user] unless is_a_reply
    rt = self.reply_to || (reply_to_stamp.blank?? nil : PrivateMessage.find_by_stamp(reply_to_stamp))
    rt ? [rt.sender_user, rt.recipient_user] : []
  end

end
