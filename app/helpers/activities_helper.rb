module ActivitiesHelper
  def hosts_activity
    Rails.cache.fetch('activity_hosts', :expires_in => ACTIVITY_CACHE_TIME) {Activity.select('distinct host').count}
  end
  def clicks_activity
    Rails.cache.fetch('activity_clicks', :expires_in => ACTIVITY_CACHE_TIME) {Activity.select('host').count}
  end
end
