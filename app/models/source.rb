class Source < ActiveRecord::Base
  has_many :imports
  has_many :posts, :class_name => 'Posts', :through => :imports

  # Mass-assignment protection
  attr_accessible :post_to, :name, :template, :url, :synchronized_at

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

  def to_param
    name
  end

  # URL to POST a reply form to
  def reply_to_post_url(post_id)
    sprintf(post_to,post_id)
  end
end
