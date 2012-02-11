class AddTimeZomeToPresentations < ActiveRecord::Migration
  def change
    add_column :presentations, :time_zone, :string, :default => DEFAULT_TIMEZONE

    Presentation.all.each {|p| p.time_zone = DEFAULT_TIMEZONE; p.save}
  end
end
