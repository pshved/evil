class AddDefaultToPresentations < ActiveRecord::Migration
  def change
    add_column :presentations, :global, :boolean, :default => false

    # We're going to select one single presentation that is the global, so we need a key here
    add_index :presentations, :global

    Presentation.all.each {|p| p.global = false; p.save }
  end
end
