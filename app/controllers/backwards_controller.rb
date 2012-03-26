class BackwardsController < ApplicationController

  # We cache both posts and the index, so we handle "read" here as well
  caches_action :index, :unless => proc {current_user}, :cache_path => proc {"index_#{params[:page]}_#{params[:read]}"},
    :expires_in => UNREG_VIEW_CACHE_TIME, :race_condition_ttl => UNREG_VIEW_CACHE_UPDATE_TIME

  def index
    read = params[:read]
    index = !read
    # NOTE that we can't render another controller's action, and we don't want to redirect (our urls should be nice!) so we render partials instead.
    if read
      # Here we may safely do a redirect, as we're not forward-compatible by URL-s (though we are backwards-compatible)
      if @post = Posts.find_last_by_back(read)
        redirect_to @post
      else
        # TODO!
      end
    elsif index
      prepare_threads
      # here we do not want to redirect: it's not nice.  Just render a partial.
      render :action => 'index'
    end
  end

end
