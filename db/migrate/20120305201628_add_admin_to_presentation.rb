class AddAdminToPresentation < ActiveRecord::Migration
  def change
    add_column :presentations, :autowrap_thread_threshold, :integer, :default => 100
    add_column :presentations, :autowrap_thread_value, :integer, :default => 100

    Presentation.all.each {|p| p.autowrap_thread_value = 100; p.autowrap_thread_threshold = 100; p.save}
  end
end
