require 'iconv'
require 'date'
class SourcesController < ApplicationController
  before_filter :find_source_by_id
  before_filter :find_import_by_post_id
  def read_post
    @post = @import.post
    redirect_to @post
  end

  after_filter :force_reply_encoding, :only => :iframe
  def iframe
    @source_reply_to = params[:orig_id]
    render :file => 'posts/sourcepost_iframe', :layout => false
  end

  def instant
    @source.instant = true
    if @source.save
      render :text => 'OK'
    else
      render :text => 'FAIL'
    end
  end

  def my_reply_to
    # Select the latest reply to the post
    # If we have a specific date, then we're just waiting.  Otherwise, we've been redirected here for the first time.
    # The reason why we need this step is because we can't send the time from javascript, as the user's time doesn't have to be accurate.  so we just take the current, and decrease some seconds from it.
    @after = params[:after].blank? ? (Time.now - 5.seconds) : DateTime.parse(params[:after])
    target = @import ? @import.post.children.where('updated_at >= ?',@after).order('created_at DESC').first : nil
    if target
      # Let's get the reply to this post
      redirect_to target
    else
      @source_reply_to = params[:orig_id]
      #render :layout => false
    end
  end

  protected
  def find_source_by_id
    @source = Source.find_last_by_name(params[:id])
  end
  def find_import_by_post_id
    @import = @source.imports.where(:back => params[:orig_id]).first
  end

  def force_reply_encoding
    response.charset = 'cp1251'
    response.body = Iconv.conv('cp1251//IGNORE//TRANSLIT','UTF-8',response.body)
  end
end
