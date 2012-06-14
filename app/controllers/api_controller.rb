require 'activity_tracker'
require 'importer'
class ApiController < ApplicationController
  # Do not track API requests in activity!
  skip_filter :log_request

  # API authorizationa by IP
  before_filter :authorize_local!, :only => [:commit_activity, :commit_clicks, :commit_sources, :import_one]

  before_filter :find_source, :only => [:import_one, :import_many]

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
    id = params[:post_id]
    # Check source
    if id.blank?
      render :text => 'NO ID!'
      return
    end
    # Get and import the post
    begin
      p = Importer.post(@source,id,@fmt,params[:page],@encoding)
      render :text => "SAVED #{p.id}"
    rescue => e
      render :text => "ERROR : #{e.to_s}"
      raise e
    end
  end

  def import_many
    s = params[:post_start].to_i
    e = params[:post_end].to_i
    # Get and import the post
    text = ""
    begin
      (s..e).each do |id|
        if p = Importer.post(@source,id,@fmt,params[:page],@encoding)
          text += "SAVED #{p.id}\n"
        else
          text += "EMPTY #{id}\n"
        end
      end
    rescue => e
      render :text => "ERROR : #{e.to_s}"
      raise e
    end
    render :text => text
  end

  # Show the desired download interval for the source.
  def interval
    source = Source.where(:name => params[:source]).first
    if source
      resp = { :timeout => source.timeout }
      if source.instant
        resp[:now] = true
        source.remove_instant!
      end
      render :json => resp
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

  def find_source
    @source = Source.find_by_url(params[:source_url])
    @fmt = params[:api]
    @encoding = params[:enc]
    # Check source
    if !@source || @fmt.blank?
      logger.warn "No source for #{source},#{id},#{fmt}"
      render :text => 'NO SOURCE!'
    end
  end

end
