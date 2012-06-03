class TextItem < ActiveRecord::Base
  belongs_to :text_container

  # Mass-assignment protection
  attr_accessible :number, :body, :revision
end
