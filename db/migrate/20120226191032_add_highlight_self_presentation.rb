class AddHighlightSelfPresentation < ActiveRecord::Migration
  def change
    add_column :presentations, :highlight_self, :boolean, :default => true
    Presentation.all.each {|p| p.highlight_self = true; p.save}
  end
end
