require 'activity_tracker'
require 'importer'
class ApiController < ApplicationController
  # Do not track API requests in activity!
  skip_filter :log_request

  # API authorizationa by IP
  before_filter :authorize_local!, :only => [:commit_activity, :commit_clicks, :commit_sources, :import_one]

  def commit_activity
    # Call activity commit functionality.
    # Guard it, just in case, into a hash timeout, so that they are not called too often by whatever reasons
    Rails.cache.fetch('activity_commit', :expires_in => ACTIVITY_CACHE_TIME/2) do
      access_tracker.commit
    end
    render :text => 'OK'
  end

  def commit_clicks
    Rails.cache.fetch('post_click_commit', :expires_in => POST_CLICK_CACHE_TIME/2) do
      post_clicks_tracker.commit
    end
    render :text => 'OK'
  end

  def commit_sources
    Rails.cache.fetch('sources_commit', :expires_in => SOURCE_UPDATE_CACHE_TIME/2) do
      source_request_tracker.commit
    end
    render :text => 'OK'
  end

  def import_one
    source = Source.find_by_url(params[:source_url])
    id = params[:post_id]
    fmt = params[:api]
    encoding = params[:enc]
    # Check source
    if !source || id.blank? || fmt.blank?
      logger.warn "No source for #{source},#{id},#{fmt}"
      render :text => 'NO SOURCE!'
      return
    end
    # Get and import the post
    begin
      p = Importer.post(source,id,fmt,params[:page],params[:enc])
      render :text => "SAVED #{p.id}"
    rescue => e
      render :text => "ERROR : #{e.to_s}"
      raise e
    end
  end

  # Show the desired download interval for the source.
  def interval
    source = Source.where(:name => params[:source]).first
    if source
      render :json => { :timeout => source.timeout }
    else
      render :text => "ERROR: not found"
    end
  end


  protected
  # Check that the request comes from localhost
  def authorize_local!
    logger.info "Will authorize: #{APP_CONFIG['api_urls']}"
    unless (APP_CONFIG['api_urls'].include? request.remote_ip)
      # NOTE: render will make rails not enter the controller
      render :text => "Unauthorized #{request.remote_ip}"
    end
  end

end
