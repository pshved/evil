class Import < ActiveRecord::Base
  belongs_to :post, :class_name => 'Posts'
  # This is an enum column handled by plugin.
  validates_columns :status
  
end
