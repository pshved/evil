module ActivitiesHelper
  # NOTE: tracker is loaded in ApplicationController
 
  def hosts_activity
    ensure_data[0]
  end

  def clicks_activity
    ensure_data[1]
  end

  protected
  def ensure_data
    @activity_data ||= (access_tracker.read || [])
  end
end
