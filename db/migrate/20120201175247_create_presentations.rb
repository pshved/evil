class CreatePresentations < ActiveRecord::Migration
  def change
    create_table :presentations do |t|
      t.integer :threadpage_size
      t.references :user

      t.timestamps
    end
    add_index :presentations, :user_id

    # Create new presentation for all users

    # This is a workaround from http://stackoverflow.com/questions/2717766/modifying-records-in-my-migration-throws-an-authlogic-error
    Authlogic::Session::Base.controller = Authlogic::ControllerAdapters::RailsAdapter.new(self)

    User.all.each {|u| u.presentations << Presentation.create ; u.save}
  end
end
