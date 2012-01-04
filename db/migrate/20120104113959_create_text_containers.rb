class CreateTextContainers < ActiveRecord::Migration
  def change
    create_table :text_containers do |t|
      t.integer :current_revision
      t.integer :arity, :default => 1

      t.timestamps
    end
  end
end
