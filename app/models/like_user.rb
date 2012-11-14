class LikeUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :post, :class_name => 'Posts'

  # Mass-assignemnt "protection"
  attr_accessible :user_id, :posts_id, :score
end
