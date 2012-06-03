class HiddenPostsUsers < ActiveRecord::Base
  belongs_to :user
  belongs_to :post, :class_name => 'Posts'

  belongs_to :hidden_post, :class_name => 'Posts', :foreign_key => 'posts_id', :conditions => %Q(action = 'hide')

  # Mass-assignemnt "protection"
  # NOTE: this model is not accessible directly
  attr_accessible :user_id, :posts_id, :action

  def self.inverse(action)
    case action
    when :show
      :hide
    when :hide
      :show
    else
      nil
    end
  end

  def self.inverse_hidden(hidden_bool)
    hidden_bool ? :show : :hide
  end

  HIDE_ACTION_MEANING = {:show => false, :hide => true}
  def self.need_hide(hide_action)
    HIDE_ACTION_MEANING[hide_action.to_sym]
  end
end
