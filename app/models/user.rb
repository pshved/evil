class User < ActiveRecord::Base
  acts_as_authentic
  # Login uniqueness
  validates_uniqueness_of :login
  # Since login is unique anyway, redefine the activerecord's auto-generated finder
  # NOTE: we can't use "alias" here, since the method is not created before we connect to DB
  def find_by_login(login)
    find_first_by_login(login)
  end

  # User-readable name
  def name
    login
  end
end
