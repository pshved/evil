# TODO: why doesn't it work?
require 'autoload/post_validations'

class Posts < ActiveRecord::Base
  belongs_to :user
  belongs_to :text_container, :autosave => true
  # touch attr updates the thread's timestamp if its post is updated
  # We need class_name since Thread is a system class
  belongs_to :thread, :touch => true, :class_name => 'Threads'
  belongs_to :parent, :class_name => 'Posts', :inverse_of => :children
  has_many :children, :class_name => 'Posts', :foreign_key => 'parent_id'

  validates_presence_of :thread
  # Each post should have a parent except for the root ones
  validates_presence_of :parent, :if => proc { |p| p.thread && (p.thread.head != p) }
  # Just checking...
  validates_presence_of :text_container

  # Other validations
  extend PostValidators
  validates_post_attrs

  # String statuses for enum/str db crunching
  ST_OPEN = 'open'
  ST_CLOSED = 'closed'

  def title
    text_container.body[0]
  end

  def body
    text_container.body[1]
  end

#  class MyValidator < ActiveModel::Validator
#    def validate(record)
#      if some_complex_logic
#        record.errors[:base] = "This record is invalid"
#      end
#    end
#  end
end
