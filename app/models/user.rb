class User < ActiveRecord::Base
  acts_as_authentic do |config|
    config.validates_format_of_login_field_options :with => /.*/
  end
  # Login uniqueness
  validates_uniqueness_of :login
  # Since login is unique anyway, redefine the activerecord's auto-generated finder
  # NOTE: we can't use "alias" here, since the method is not created before we connect to DB
  def self.find_by_login(login)
    find_last_by_login(login)
  end

  has_many :private_messages
  has_many :unread_messages, :class_name => 'PrivateMessage', :conditions => {:unread => true}

  attr_accessor :current_password

  # For use in form
  validates_each :current_password do |record, attr, value|
    # Do not try to validate "current_password" if the user's being created
    if record.persisted?
      record.errors.add attr, I18n.t('is_invalid') unless UserSession.new(:login => record.login, :password => record.current_password).valid?
    end
  end

  # User-readable name
  def name
    login
  end
  # URL id
  def to_param
    login
  end
  def self.from_param(p)
    find_by_login(p)
  end

  # Roles
  has_and_belongs_to_many :roles
  # required by auth plugin
  def role_symbols
    (roles || []).map {|r| r.name.to_sym}
  end

  before_create do
    # Add default role
    roles << Role.find_or_create_by_name('user') if roles.count == 0
    # Add default presentation
    presentations << Presentation.create if presentations.empty?
  end


  # Presentations
  has_many :presentations
  belongs_to :default_presentation, :class_name => 'Presentation'
  def current_presentation(cookies = {})
    result = nil
    # Try to load the presentation for the current user recorded in cookies
    if presentation_name = cookies[:presentation_name]
      result = presentations.where(['name = ?', presentation_name]).first
    end
    # If we couldn't find a presentation via cookies, just show the default.  We should not show an error here!
    result ||= default_presentation
    result ||= presentations.first
    result or raise "Can't find current presentation for user #{self.login}"
  end

  #Hidden posts
  has_many :hide_actions, :class_name => 'HiddenPostsUsers'
  has_many :hidden_posts, :class_name => 'Posts', :through => :hide_actions

  # Signature
  belongs_to :signature, :autosave => true, :class_name => 'TextContainer', :foreign_key => 'signature'
  validates_length_of :signature_body, :maximum => 333
  protected
  def ensure_signature
    self.signature ||= TextContainer.make('')
  end
  public
  def signature_body=(x)
    ensure_signature[0] = x
  end
  def signature_body
    ensure_signature.body[0]
  end
  def formatted_signature
    ensure_signature.filtered[0]
  end
  # Belongs_to associations, unlike has_one, need to be saved explicitly
  before_save do
    signature.save
  end

  # Caching
  def user_roles_key
    current_user ? current_user.roles.map(&:name).join(',') : 'guest'
  end
end
