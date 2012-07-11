class Pazuzu < ActiveRecord::Base
  # We should reload all threads after pazuzing somebody; this is handled via touching the user.
  belongs_to :user, :touch => true
  belongs_to :bastard, :class_name => 'User'

  validate do |ban|
    # Check if bastard was specified but not found
    if ban.bastard.blank? && !ban.bastard_name.blank?
      errors.add(:bastard_name, I18n.t('cant_find'))
    # Something should be specified
    elsif ban.bastard.blank? && ban.unreg_name.blank? && ban.host.blank?
      errors.add(:base, I18n.t('cant_ban_nobody'))
    end
  end

  validates_presence_of :user
  validates_uniqueness_of :user_id, :scope => [:user_id, :host, :unreg_name], :message => I18n.t('cant_ban_twice')


  attr_accessor :use_bastard, :use_host, :use_unreg_name
  attr_accessor :bastard_name
  attr_accessible :bastard, :host, :unreg_name, :bastard_name, :use_bastard, :use_host, :use_unreg_name

  # Apply use_* forward
  before_validation do
    self.bastard = nil if use_bastard == '0'
    self.unreg_name = nil if use_unreg_name == '0'
    self.host = nil if use_host == '0'
    true
  end

  #...and backwards
  def init_use
    if persisted?
      @use_bastard = !self.bastard.blank?
      @use_host = !self.host.blank?
      @use_unreg_name = !self.unreg_name.blank?
    else
      @use_bastard = self.unreg_name.blank?
      @use_host = !self.unreg_name.blank?
      @use_unreg_name = !self.unreg_name.blank?
    end
  end

  def bastard_name
    @bastard_name || (bastard.blank? ? nil : bastard.login)
  end

  before_validation do
    self.bastard = User.find_by_login self.bastard_name
  end

  validate do |ban|
    # You can't ban self!
    if !ban.user.blank? && ban.bastard == ban.user
      errors.add(:base, I18n.t('cant_ban_self'))
    end
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

  def equals other_pazuzu
    def nml(x)
      x.blank? ? nil : x
    end
    [ nml(other_pazuzu.bastard), nml(other_pazuzu.host), nml(other_pazuzu.unreg_name) ] ==
      [ nml(self.bastard), nml(self.host), nml(self.unreg_name) ]
  end
end
