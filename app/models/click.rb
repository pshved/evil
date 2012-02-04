require 'autoload/utils'

class Click < ActiveRecord::Base
  belongs_to :post

  def click!(user = nil, ip = '127.0.0.1')
    new_clicker = user ? user.login : gethostbyaddr(ip)
    self.clicks ||= 0
    self.clicks += 1 if last_click != new_clicker
    self.last_click = new_clicker
    save
  end
end

