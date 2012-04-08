module ActivitiesHelper
  # NOTE: tracker is loaded in ApplicationController
 
  def hosts_activity
    access_tracker.hosts_activity
  end

  def clicks_activity
    access_tracker.clicks_activity
  end
end
