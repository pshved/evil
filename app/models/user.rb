class User < ActiveRecord::Base
  acts_as_authentic
  # Login uniqueness
  validates_uniqueness_of :login
  # Since login is unique anyway, redefine the activerecord's auto-generated finder
  # NOTE: we can't use "alias" here, since the method is not created before we connect to DB
  def find_by_login(login)
    find_first_by_login(login)
  end

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

  # Roles
  has_and_belongs_to_many :roles
  # required by auth plugin
  def role_symbols
    (roles || []).map {|r| r.name.to_sym}
  end

  before_save do
    roles << Role.find_or_create_by_name('user') if roles.count == 0
  end


  # Presentations
  has_many :presentations
  # TODO: users should have several presentations, one of which should be recorded in cookies as the current one.
  def current_presentation
    presentations[0] or raise "Can't find current presentation for user #{self.login}"
  end
end
