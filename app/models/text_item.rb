class TextItem < ActiveRecord::Base
  belongs_to :text_container

  belongs_to :user

  # Mass-assignment protection
  attr_accessible :number, :body, :revision, :user
end
