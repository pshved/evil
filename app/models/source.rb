class Source < ActiveRecord::Base
  has_many :imports
  has_many :posts, :class_name => 'Posts', :through => :imports

  def self.record_accesses_to(sources)
    where(:id => sources).update_all :synchronized_at => Time.now
  end

  # Show the timeout between API requests.
  #
  # If the source was accessed during the latest 5 minutes, the timeout is 30 seconds.  Otherwise, it's 10 minutes.
  # For x-board, this is confirmed by http://x.mipt.cc/?read=18911
  def timeout
    if Time.now - synchronized_at > 5.minutes
      10.minutes
    else
      30.seconds
    end
  end
end
