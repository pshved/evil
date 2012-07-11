class CreatePazuzus < ActiveRecord::Migration
  def change
    create_table :pazuzus do |t|
      t.references :user
      t.references :bastard
      t.string :unreg_name
      t.string :host

      t.timestamps
    end
    add_index :pazuzus, :user_id
    add_index :pazuzus, :bastard_id
    add_index :pazuzus, [:user_id, :bastard_id, :unreg_name, :host], :unique => true
  end
end
