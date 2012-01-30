class AddFilterToTextContainer < ActiveRecord::Migration
  def change
    add_column :text_containers, :filter, :enum, :limit => [:board, :html], :default => :board
    # This should be replaced for a larger database.. but it's the beginning, we may forget about it so far
    TextContainer.all.each {|tc| tc.filter = :board}
  end
end
