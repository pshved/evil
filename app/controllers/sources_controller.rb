require 'iconv'
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
