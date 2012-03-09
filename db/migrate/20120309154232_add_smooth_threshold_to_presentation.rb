class AddSmoothThresholdToPresentation < ActiveRecord::Migration
  def change
    add_column :presentations, :smooth_threshold, :integer
  end
end
