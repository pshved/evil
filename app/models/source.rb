class Source < ActiveRecord::Base
  has_many :imports
  has_many :posts, :class_name => 'Posts', :through => :imports
end
