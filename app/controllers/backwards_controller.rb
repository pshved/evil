class BackwardsController < ApplicationController
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
