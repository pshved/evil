require 'activity_tracker'
class ApiController < ApplicationController
  before_filter :authorize_local!, :only => [:commit_activity]
  def commit_activity
    # Call activity commit functionality.
    # Guard it, just in case, into a hash timeout, so that they are not called too often by whatever reasons
    Rails.cache.fetch('activity_commit', :expires_in => ACTIVITY_CACHE_TIME/2) do
      tracker.commit
    end
    render :text => 'OK'
  end

  def import
    # do noting
  end


  protected
  # Check that the request comes from localhost
  def authorize_local!
    unless (request.remote_ip =~ /^127\./)
      # NOTE: render will make rails not enter the controller
      render :text => 'Unauthorized'
    end
  end

end