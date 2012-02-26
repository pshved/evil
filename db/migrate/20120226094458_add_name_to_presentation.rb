class AddNameToPresentation < ActiveRecord::Migration
  def change
    add_column :presentations, :name, :string
    add_index :presentations, :name
    add_index :presentations, [:user_id, :name]

    add_column :users, :default_presentation_id, :integer

    # Presentations should have unique names; create names for them
    Presentation.all.each{|p| p.name = 'default'; p.save}
  end
end
