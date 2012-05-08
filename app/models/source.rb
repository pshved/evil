class Source < ActiveRecord::Base
  has_many :imports
  has_many :posts, :class_name => 'Posts', :through => :imports

  def self.record_accesses_to(sources)
    where(:id => sources).update_all :synchronized_at => Time.now
  end
end
