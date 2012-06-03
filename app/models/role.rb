class Role < ActiveRecord::Base
  #acts_as_enumerated -- when really needed
  validates_presence_of :name
  has_and_belongs_to_many :users
  attr_accessible :name
end
