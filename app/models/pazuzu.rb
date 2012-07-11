class Pazuzu < ActiveRecord::Base
  # We should reload all threads after pazuzing somebody; this is handled via touching the user.
  belongs_to :user, :touch => true
  belongs_to :bastard, :class_name => 'User'

  validate do |ban|
    if ban.bastard.blank? && ban.unreg_name.blank? && ban.host.blank?
      errors.add(:base, "Internal error: try banning again!")
    end
  end

  validates_presence_of :user
  validates_uniqueness_of :user_id, :scope => [:user_id, :host, :unreg_name], :message => 'has already banned this bastard'


  attr_accessor :use_bastard, :use_host, :use_unreg_name
  attr_accessor :bastard_name
  attr_accessible :bastard, :host, :unreg_name, :bastard_name, :use_bastard, :use_host, :use_unreg_name

  def bastard_name
    @bastard_name || (bastard.blank? ? nil : bastard.login)
  end

  before_save do
    debugger
    self.bastard = User.find_by_login self.bastard_name
  end


  # Check if this rule actually bans the post given
  def bans(post)
    return false unless post

    false ||
      ( host.blank? ? false : post.host == host) ||
      ( bastard.nil? ? false : post.author_id == bastard.id ) ||
      ( unreg_name.blank? ? false : post.unreg_name == unreg_name ) ||
    false
  end
end
