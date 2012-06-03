class ModerationAction < ActiveRecord::Base
  belongs_to :post, :class_name => 'Posts'
  belongs_to :user

  # Mass-assignment protection
  attr_accessible :post, :user, :reason
end
