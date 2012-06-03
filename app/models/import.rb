class Import < ActiveRecord::Base
  self.table_name = "imports"

  belongs_to :post, :class_name => 'Posts'
  belongs_to :source

  # Check that there's no two imported posts with the same ID (not strict because we may want to return a value to an importer)
  validates_uniqueness_of :back, :scope => [:source_id]

  # Mass-assignment protection
  # NOTE that this model is not accessible from public, only from importers
  attr_accessible :source_id, :back, :reply_to

end
