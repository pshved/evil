class CreateActivities < ActiveRecord::Migration
  def change
    create_table :activities do |t|
      t.string :host

      t.timestamps
    end

    add_index :activities, :host
    add_index :activities, :created_at
  end
end
