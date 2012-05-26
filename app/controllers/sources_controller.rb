class SourcesController < ApplicationController
  before_filter :find_source_by_id
  def read_post
    @post = @source.imports.where(:back => params[:orig_id]).first.post
    redirect_to @post
  end

  protected
  def find_source_by_id
    @source = Source.find_last_by_name(params[:id])
  end
end
