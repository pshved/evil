class Presentation < ActiveRecord::Base
  belongs_to :user

  composed_of :tz, :class_name => 'TZInfo::Timezone', :mapping => %w(time_zone time_zone)
end
