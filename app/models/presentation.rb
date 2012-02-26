class Presentation < ActiveRecord::Base
  belongs_to :user
  composed_of :tz, :class_name => 'TZInfo::Timezone', :mapping => %w(time_zone time_zone)

  # Returns default presentation
  def self.default
    Presentation.new(:time_zone => DEFAULT_TZ.name,
                     :threadpage_size => Configurable[:default_homepage_threads] || Kaminari.config.default_per_page
                    )
  end
end
