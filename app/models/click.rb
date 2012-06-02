require 'autoload/utils'

class Click < ActiveRecord::Base
  belongs_to :post, :class_name => 'Posts'

  # Mass-assignment security
  attr_accessible :last_click, :clicks

  def self.clicker(user = nil, ip = '127.0.0.1')
    # We don't need to get a nice host here.
    user ? user.login : ip
  end

  # Commit the sequence of clicks into the database
  # Sequence is an arrays of tuples (post_id, clicker), that represents a sequence of clicks to posts
  def self.replay(sequence)
    # hash:  post_id => [clicks, last_click]
    post_clicks = {}
    # oops, I noticed that sequence returns strings as post_ids... it can't pick the stuff from hash later!
    sequence.map!{|tuple| [tuple[0].to_i, tuple[1]]}
    # Load posts once (hash: id => activerecord object), and load clicks alongside to determine the latest clicker for each post.  We also load threads to touch them.
    posts = {}
    # Since post_ids may be not valid, we should clear them out, keeping only valid posts.
    # NOTE: we can't use Posts.find here because it throws an exception if not all ID-s have been found.
    valid_post_ids = Posts.where(:id => sequence.map{|tuple| tuple[0]}).map {|p| p.id}
    # Now all the post IDs are really posts, and we may load them and their associations
    Posts.find(valid_post_ids, :include => ['click','thread']).each {|p| posts[p.id] = p}
    # Replay the sequence.  Count clicks made during this sequence.
    sequence.each do |tuple|
      post_id, clicker = tuple
      # Load current post and bucket
      post = posts[post_id]

      # Since we don't try to find posts before recording their access, check if the post has actually been found
      next unless post
      # Handle post that has never been clicked
      last_click = post.click ? post.click.last_click : nil
      bucket = (post_clicks[post_id] ||= [0,last_click])
      # This will write into hash bucket even if it has just been created
      bucket[0] +=1 if bucket[1] != clicker
      bucket[1] = clicker
    end
    # Update clicks and posts
    # Unless we create a transaction, Rails will create a separate transaction for each update below.  This would be a disaster.
    # We also make some use of the transaction.  We touch each thread (to invalidate its cache) only once, and we may do it at any time of the transaction.  If it was not for one bug transaction, the thread could've been updated _before_ all post access times had been updated.
    transaction do
      # Record of touched threads (to avoid touching one thread twice)
      already_touched = {}
      # Now check each post click record, and update post clicks and threads.
      post_clicks.each do |post_id, data|
        add, last_click = data
        next if add == 0

        # We have something to add, do it
        post = posts[post_id]
        if post.click
          # To ensure we don't have a race condition here, call this procedure from one thread only.  This will be ensured by scheduler.
          post.click.update_attributes(:last_click => last_click, :clicks => post.clicks + add)
        else
          # LOL.  This should be post.create_click, but as post_id is the primary key (my bad), it doesn't work.
          post.build_click(:clicks => add, :last_click => last_click)
          post.click.save
        end
        # Now invalidate the cache for the thread if necessary
        # The second disjunct is an estimation of probability that none of the clicks would have trigger the update.  It should be (1 - 1/cdr)^add
        approx = (1.0 - add.to_f/CLICK_DELAY_RATE + (add*(add-1)).to_f/2/CLICK_DELAY_RATE/CLICK_DELAY_RATE)
        if (!already_touched[post.thread.id]) && ((post.click.clicks < CLICK_UPDATE_THRESHOLD) || (rand() > approx))
          post.thread.touch
          already_touched[post.thread.id] = true
        end
      end
    end
  end
end

