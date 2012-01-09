# TODO: fix autoloader
require 'autoload/utils'

class PrivateMessage < ActiveRecord::Base
  belongs_to :sender_user, :class_name => 'User'
  belongs_to :recipient_user, :class_name => 'User'
  belongs_to :text_container, :autosave => true
  belongs_to :reply_to, :class_name => 'PrivateMessage'
  has_many :replies, :foreign_key => 'reply_to_id', :class_name => 'PrivateMessage'

  validates_presence_of :text_container
  validates_presence_of :sender_user
  ## Instead of recipient_user, we validate its login
  #validates_presence_of :recipient_user
  # Body should not be empty
  validates_length_of :msg_body, :in => 1..500, :allow_blank => false

  # Form validation
  attr_accessor :recipient_user_login, :msg_body, :current_user, :reply_to_stamp

  # For use in form
  validates_each :recipient_user_login do |record, attr, value|
    record.errors.add attr, 'does not exist' unless User.find_by_login(value)
  end

  before_validation do
    self.sender_user = self.current_user
    self.recipient_user = User.find_by_login(recipient_user_login)
    self.text_container = TextContainer.make(msg_body)
    self.reply_to = reply_to_stamp.blank?? nil : PrivateMessage.find_by_stamp(reply_to_stamp)
    true
  end

  # Return query template for all messages sent to/received by a given user.  You should finalize the query by applying .all or something like this to the returned object.
  def self.all_for(user)
    return [] if user.nil?
    PrivateMessage.where(['sender_user_id = :u OR recipient_user_id = :u', {:u => user.id}]).order('created_at DESC')
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
  validates_uniqueness_of :stamp
  def find_by_stamp(s)
    PrivateMessage.find_first_by_stamp(s)
  end

  def body
    text_container ? text_container.body[0] : ''
  end
  def filtered_body
    text_container ? text_container.filtered[0] : ''
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
