class AddTemplateToSources < ActiveRecord::Migration
  def change
    add_column :sources, :template, :string
  end
end
