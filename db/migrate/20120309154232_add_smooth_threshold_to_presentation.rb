class AddSmoothThresholdToPresentation < ActiveRecord::Migration
  def change
    add_column :presentations, :smooth_threshold, :integer, :default => 10

    ActiveRecord::Base.connection.execute('UPDATE presentations SET smooth_threshold = 10')
  end
end
