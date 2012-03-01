module ActivitiesHelper
  def hosts_activity
    Activity.select('distinct host').count
  end
  def clicks_activity
    Activity.select('host').count
  end
end
