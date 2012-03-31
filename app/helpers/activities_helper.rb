module ActivitiesHelper
  # NOTE: tracker is loaded in ApplicationController
 
  def hosts_activity
    tracker.hosts_activity
  end

  def clicks_activity
    tracker.clicks_activity
  end
end
