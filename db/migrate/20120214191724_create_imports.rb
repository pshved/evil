class CreateImports < ActiveRecord::Migration
  def change
    create_table :imports do |t|
      t.enum :status, :limit => [:queued, :started, :finished], :default => :queued
      t.references :post

      t.timestamps
    end
    add_index :imports, :post_id
  end
end
