# coding: utf-8
# As we work with strings here, we should set encoding for them

require 'markup/boardtags.rb'

module PostsHelper
  def fast_link
    return @_post_fast_link if @_post_fast_link
    # Render a test link with placeholders
    magic = 47382929372 # Beware! should not be equal to a post id!
    pl = link_to 'TITLE_PH', post_path(magic), :name => magic

    # We abuse that, in HTML, link address and anchor name are before the text.
    md = /^(.*)#{magic}(.*)#{magic}(.*)TITLE_PH(.*)$/u.match(pl) or raise "WTF!  how come a link became #{pl} ???"
    md1 = md[1]
    md2 = md[2]
    md3 = md[3]
    md4 = md[4]

    # Note to_s near "id"!  Otherwise, ActiveRecord (or Ruby) will convert it to ASCII instead of UTF-8
    @_post_fast_link = proc {|buf,p,title_override| buf << md1 << p.id.to_s << md2 << p.id.to_s << md3 << (title_override || p.htmlsafe_title.strip) << md4}

  end

  # Only URL, without "<a>" tag
  def fast_post_url
    return @_post_fast_url if @_post_fast_url
    # Render a test link with placeholders
    magic = 47382929372 # Beware! should not be equal to a post id!
    pl = post_path(magic)

    # We abuse that, in HTML, link address and anchor name are before the text.
    md = /^(.*)#{magic}(.*)$/u.match(pl) or raise "WTF!  how come a link became #{pl} ???"
    md1 = md[1]
    md2 = md[2]

    # Note to_s near "id"!  Otherwise, ActiveRecord (or Ruby) will convert it to ASCII instead of UTF-8
    @_post_fast_url = proc {|buf,p| buf << md1 << p.id.to_s << md2}

  end

  def fast_user
    return @_user_fast_link if @_user_fast_link
    # Render a test link with placeholders
    magic = 47382929372 # Beware! should not be equal to a user id!
    pl = link_to 'TITLE_PH', user_path(magic)
    pl.force_encoding('UTF-8')

    # We abuse that, in HTML, link address is before the text.
    md = /^(.*)#{magic}(.*)TITLE_PH(.*)$/u.match(pl)
    # The regexp is unicode, but the match data is ascii (why??)
    md1 = md[1].force_encoding('UTF-8')
    md2 = md[2].force_encoding('UTF-8')
    md3 = md[3].force_encoding('UTF-8')

    @_user_fast_link = proc {|buf,login| buf << md1 << login << md2 << h(login) << md3}

  end

  # We both cache links, and translations, as translating the same string thousands of times takes .05 sec.  The accompanying block should return a pair of values, iftrue and iffalse.
  def fast_hide
    return @_post_fast_hide if @_post_fast_hide
    # Render a test link with placeholders
    magic = 47382929372 # Beware! should not be equal to a post id!
    magic_class = 'MAGIC_ANOTHER_ACTION'
    pl = link_to 'TITLE_PH', toggle_showhide_post_path(magic), :class => "action subthread #{magic_class}"

    # We abuse that, in HTML, link address is before the text.
    md = /^(.*)#{magic}(.*)#{magic_class}(.*)TITLE_PH(.*)$/u.match(pl) or raise "WTF!  how come a link became #{pl} ???"
    md1 = md[1]
    md2 = md[2]
    md3 = md[3]
    md4 = md[4]

    iftrue, iffalse = yield

    # Note to_s near "id"!  Otherwise, ActiveRecord (or Ruby) will convert it to ASCII instead of UTF-8
    @_post_fast_hide = proc do |buf,p,should_hide|
      buf <<
        md1 << p.id.to_s <<
        # Reverse this: should_hide means if we "should hide the subthread"
        md2 << (should_hide ? 'show' : 'hide') <<
        md3 << (should_hide ? iftrue : iffalse) << md4
    end

  end

  # We both cache links, and translations, as translating the same string thousands of times takes .05 sec.  The accompanying block should return a pair of values, iftrue and iffalse.
  def fast_liked
    return @_post_fast_liked if @_post_fast_liked
    # Render a test link with placeholders
    magic = 47382929372 # Beware! should not be equal to a post id!
    magic_class = 'MAGIC_ANOTHER_ACTION'
    pl = link_to 'TITLE_PH', toggle_like_post_path(magic), :class => "like action #{magic_class}"

    # We abuse that, in HTML, link address is before the text.
    md = /^(.*)#{magic}(.*)#{magic_class}(.*)TITLE_PH(.*)$/u.match(pl) or raise "WTF!  how come a link became #{pl} ???"
    md1 = md[1]
    md2 = md[2]
    md3 = md[3]
    md4 = md[4]

    iftrue, iffalse = yield

    # Note to_s near "id"!  Otherwise, ActiveRecord (or Ruby) will convert it to ASCII instead of UTF-8
    @_post_fast_liked = proc do |buf,p,should_liked|
      buf <<
        md1 << p.id.to_s <<
        # Reverse this: should_liked means if we "should liked the subthread"
        md2 << (should_liked ? 'like' : 'dislike') <<
        md3 << (should_liked ? iftrue : iffalse) << md4
    end

  end
  def unless_deleted(post)
    # Cache user's permission to view deleted posts
    if @_can_see_deleted.nil?
      @_can_see_deleted = permitted_to? :see_deleted, :posts
    end
    yield unless !@_can_see_deleted && post.deleted
  end

  # Returns proc that returns if the user name given should be highlighted.  Encapsulates current user and presentation.
  def should_highlight
    return @_should_highlight if @_should_highlight
    # Load settings
    settings_allow = current_presentation.highlight_self
    # Load current user's nickname
    cu = current_user
    cu = cu.to_css_id if cu

    @_should_highlight = proc {|l| settings_allow && (l == cu)}
  end

  def time_for_header(time,tz)
    tz.utc_to_local(time).strftime("%d.%m.%Y %H:%M")
  end

  # Casted after the tree is printed.  Changes the class of the span the current post's header is wrapped, so that it looks differently
  def post_span_replace(tree_string,post,user = current_user)
    user_cssid = user ? user.to_css_id : nil
    # NOTE: I tried to use "provide" instead of "content_for" to avoid unnecessary concatenation, but it didn't work.  Instead, we check if the content has been supplied before printing it. (TODO: check if slow!)
    # If we're not showing any particular post, do not add any styles
    if post && !(content_for? :current_post_style)
      provide :current_post_style, <<EOS
span.css#{post.id} a {
  font-weight: bold;
  color: #000;
  &:visited {}
  &:hover   { color: #000; }
}
EOS
    end

    # Not only we check if the user login is supplied but also if we actually want to highlight it
    if user_cssid && should_highlight[user_cssid] && !(content_for? :current_user_style)
      # NOTE that the CSS classes should coincide with those in user_link function in app/helpers/application_helper.rb
      provide :current_user_style, <<EOS
span.uid#{user_cssid} a {
  font-weight: bold;
  color: red;
}
EOS
    end
    tree_string
  end

  def fast_print_username(buf,post)
    # NOTE: keep this in sync with user_link in application_helper.rb!

    # Due to the speed concerns, we use user_login here instead of user.login, so we don't need to load users
    if this_login = post.user_login
      # Highlight message, if necessary
      # See post_span_replace where the uid is used.
      buf << %Q(<span class="user-other uid#{post.cssid}">)
      fast_user[buf,this_login]
      buf << %Q(</span>)
    else
      buf << %Q(<span class="user-unreg">) << (post.unreg_name || "NIL") << %Q(</span>)
    end
  end

  # Print raw html (no ERB or HAML!) for a line of this post.  User view settings are ignored for now
  def fast_print(post, tz, buf = '', view_opts = {})
    # We'll use string as a "StringBuffer", appending to a mutable string instead of concatenation

    # Some users may view deleted posts (if they're privileged enough).
    # See the closing tag the end of the function
    buf << %Q(<span class="post-deleted">) if post.deleted

    # Post title (link or plain, depending on whether it's the current post)
    # The css class with post.id is used to render the same thread regardless what post is current, making the thread browsing easier.  See post_span_replace for how it works.
    buf << %Q(<span class="post-oneline css#{post.id}">)
    # This already prints to the buf!  Do not append, or your memory will blow!
    fast_link[buf,post]
    buf << %Q(</span>)
    # (url)/(pic) marks
    marks = post.marks.map(&:to_s)
    # If the title contains url, add it to the "url" mark
    url_link = nil
    unless post.follow.blank?
      url_link = post.follow
      marks |= ['url']
    end
    marks.each do |mark|
      if url_link && mark == 'url'
        buf << ' <span class="post-mark">(<a href="' << url_link << '">' << mark << '</a>)</span>'
      else
        buf << ' <span class="post-mark">(' << mark << ")</span>"
      end
    end
    # Now (+)/(-) marks
    if post.empty_body?
      buf << ' (-)'
    else
      if view_opts[:plus]
        # Let's insert a JavaScript "+"!
        buf << %Q( <a class="postbody" id="sh#{post.id}" onclick="pbsh(#{post.id});" href=")
        fast_post_url[buf,post]
        buf << %Q(">(+)</a>)
      end
    end
    # post clicks
    if post.clicks != 0 && post.clicks != '0'
      buf << ' <span class="post-clicks">('
      if post.rating != 0 && post.rating != '0'
        # FIXME: style
        buf << '<b>' << post.rating.to_s << '</b>'
        buf << '/'
      end
      buf << post.clicks.to_s << ")</span>"
    end

    buf << ' - '
    fast_print_username(buf,post)
    buf << " (#{post.host}) "
    buf << ' - '
    buf << %Q(<span class="post-timestamp">) << time_for_header(post.created_at,tz) << %Q(</span>)

    # See the opening tag the end of the function
    buf << %Q(</span>) if post.deleted
  end

  def fast_showhide(post,tree,thread_info,buf = '')
    # Post hidden mark and hide/show modifier
    # NOTE: the attrs to hidden_by are ignored for the FasterPost, but they're left for compatibility with the usual Posts.
    # For FasterPost, :user => current_user has already been applied in the fetching sql, so we do not specify it here
    hidden = post.hidden_by?(:user => current_user, :thread_info => thread_info, :show_all => @show_all_posts) 
    # Because showhide does not have any effect in single-post view, do not display this all
    unless @show_all_posts
      # Unfortunately, we can't use permissions here (until we optimize them)
      buf << ' '
      fast_hide_prepared = fast_hide {[t("Show subtree"), t("Hide subtree")]}
      if tree[post.id] && !tree[post.id].empty?
        if hidden
          fast_hide_prepared[buf,post,true]
        else
          fast_hide_prepared[buf,post,false]
        end
      end
    end
    return !hidden
  end

  def fast_hidden_bar
    return @_post_fast_hidden_bar if @_post_fast_hidden_bar

    s1 = %Q[<span class="action">#{t('Hidden')}</span>: (#{t('Replies')}: ]
    s2 = ", #{t('Latest Reply')}: "
    s3 = " #{t('From')} "
    s4 = ")"

    # Note to_s near "id"!  Otherwise, ActiveRecord (or Ruby) will convert it to ASCII instead of UTF-8
    @_post_fast_hidden_bar = proc do |buf,p,info,tz|
      # Tree may come without info (see "latest posts," for instance)
      replies = (info[:size] || 1) - 1
      if replies > 0
        buf << %Q(<div class="hidden-bar">)
        buf << s1 << %Q(<span class="count">) << replies.to_s << %Q(</span>) << s2
        latest_subthread_post = info[:latest]
        fast_link[buf,latest_subthread_post,time_for_header(latest_subthread_post.created_at,tz)]
        buf << s3
        fast_print_username(buf,latest_subthread_post)
        buf << s4
        buf << "</div>"
      end
    end
  end

  # This yields HTML code for the tree that starts with the +start+ post, but doesn't highlight the current post.
  def fast_generic_tree(buf,tree,start,info = {}, tz = DEFAULT_TZ, view_opts = {})
    # If start is nil, then we're printing the index, and skip the post itself.
    if start
      this_info = info[start.id] || {}
      pcl = 'post-header'
      pcl << ' pazuzued' if this_info[:pazuzued]
      pcl << ' sm' if view_opts[:smoothed]
      buf << %Q(<div class="#{pcl}" id="p#{start.id}">)
      # Since the thread is wrapped into <div>, we should place the up-marker to the same line.
      buf << "^ " if view_opts[:smoothed]
      unless_deleted(start){fast_print(start,tz,buf,view_opts)}

      # Likes
      # FIXME: likes
      flp = fast_liked {[t("Like"),t("Unlike")]}
      if start.score == 0
        buf << %Q( <a id="like#{start.id}" class="like action" href="#">Like</a>)
      else
        buf << %Q( <a id="like#{start.id}" class="like action" href="#">Unlike</a>)
      end


      # Do not show (+++) if we don't show a usual (+), since it's not going to work anyway
      if view_opts[:plus] && this_info[:has_nonempty_body]
        buf << %Q( <a id="exp#{start.id}" class="subthreadbody action" href="#">+++</a>)
      end

      # Show if post is hidden, and display the toggle
      post_shown = fast_showhide(start,tree,info,buf)
      buf << %Q(</div>)
      unless post_shown || @show_all_posts
        # Show that the post is hidden, and the info about the subthread
        fast_hidden_bar[buf,start,this_info,tz]
        return buf
      end
    end
    kids = start ? tree[start.id] : nil
    return buf unless kids
    # If this node is smoothed, do not insert a new level of the list, just continue the parent's.
    smoothed = (info[start.id] || {})[:smoothed]
    # For that, we should close the <li> tag (if we have any kids).  Otherwise, we open a new level of the list, and close it after we lay out the children.
    # Recursive Requirement: if this thread is smoothed, then fast_generic_tree returns with a closed <li> tag.  Otherwise, it returns with an opened <li> tag!
    buf << %Q(</li>\n) if smoothed
    buf << %Q(<ul>\n) unless smoothed
    kids.each do |child|
      unless_deleted child do
        buf << %Q(<li>)
        fast_generic_tree(buf,tree,child,info,tz,view_opts.merge(:smoothed => smoothed))
        # See Recursive Requirement above for use of "smoothed" here
        buf << %Q(</li>\n) unless smoothed
      end
    end
    buf << %Q(</ul>\n) unless smoothed
  end

  def fast_tree(buf,tree,start,info = {}, tz = DEFAULT_TZ, view_opts = {})
    prepped = fast_generic_tree(buf,tree,start,info,tz,view_opts)
    post_span_replace(prepped,@post,current_user)
  end

  def fast_tree_presentation(buf,tree,start,info = {}, presentation = nil)
    return fast_tree(buf,tree,start,info) unless presentation
    fast_tree buf,tree,start,info,presentation.tz, :plus => presentation.plus
  end

  # Returns the cached HTML for the tree of the "thr" thread.  Accounts for @post.
  def fast_tree_cache(thr,buf,start,presentation)
    # Either we have already fetched the thread from cache, or we're to load it
    prepped = thr.cached_html || fast_usual_tree_cache(thr,buf,start,presentation)
    # Replace current post's class
    post_span_replace(prepped,@post,current_user)
  end

  def fast_usual_tree_cache(thr,buf,start,presentation)
    # All cache key options are moved to controller's thread_cache_key
    cache_key = thr.cache_key || thread_cache_key(thr,presentation)
    # Get the prepared thread to incur the current post into it
    prepped = Rails.cache.fetch(cache_key, :expires_in => THREAD_CACHE_TIME) do
      logger.debug "Tree for key: '#{cache_key}' miss!"
      fast_generic_tree(buf,thr.build_subtree_fast,thr.fast_head,thr.hides_fast,presentation.tz,{:plus => presentation.plus})
    end
  end


  # Now the regular helpers
  def make_button(button)
    if btr = BUTTON_REGISTRY[button]
      haml_tag 'button', :type => 'button', :class => 'style', :name => btr[:name], :accesskey => btr[:accesskey], :title => btr[:title], :onclick => btr[:onclick], :tabindex => 5 do
        if btr[:html]
          haml_concat btr[:html]
        else
          haml_concat (html_escape button)
        end
      end
    end
  end
end
