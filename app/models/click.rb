require 'autoload/utils'

class Click < ActiveRecord::Base
  # Spawning doesn't work on my setup without this :-(
  include Spawn

  belongs_to :post, :class_name => 'Posts'

  def self.clicker(user = nil, ip = '127.0.0.1')
    user ? user.login : gethostbyaddr(ip)
  end
  def click!(user = nil, ip = '127.0.0.1')
    if (clicks < CLICK_UPDATE_THRESHOLD)
      # Click, save, and invalidate cache
      click_and_save(user,ip)
      post.thread.touch
    else
      # Defer computation and click invalidation
      # Invalidate caches for this thread if necessary
      spawn do
        click_and_save(user,ip)
        if rand() < 1.0/CLICK_DELAY_RATE
          post.thread.touch
        end
      end
    end
  end

  protected
  def click_and_save(user,ip)
    new_clicker = Click.clicker(user,ip)
    self.clicks ||= 0
    self.clicks += 1 if last_click != new_clicker
    self.last_click = new_clicker
    save
  end
end

