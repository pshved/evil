# coding: utf-8
# As we work with strings here, we should set encoding for them

require 'markup/boardtags.rb'

module PostsHelper
  def fast_link
    return @_post_fast_link if @_post_fast_link
    # Render a test link with placeholders
    magic = 47382929372 # Beware! should not be equal to a post id!
    pl = link_to 'TITLE_PH', post_path(magic)

    # We abuse that, in HTML, link address is before the text.
    md = /^(.*)#{magic}(.*)TITLE_PH(.*)$/u.match(pl) or raise "WTF!  how come a link became #{pl} ???"
    md1 = md[1]
    md2 = md[2]
    md3 = md[3]

    # Note to_s near "id"!  Otherwise, ActiveRecord (or Ruby) will convert it to ASCII instead of UTF-8
    @_post_fast_link = proc {|buf,p| buf << md1 << p.id.to_s << md2 << h(p.title.strip) << md3}

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
    pl = link_to 'TITLE_PH', toggle_showhide_post_path(magic)

    # We abuse that, in HTML, link address is before the text.
    md = /^(.*)#{magic}(.*)TITLE_PH(.*)$/u.match(pl) or raise "WTF!  how come a link became #{pl} ???"
    md1 = md[1]
    md2 = md[2]
    md3 = md[3]

    iftrue, iffalse = yield

    # Note to_s near "id"!  Otherwise, ActiveRecord (or Ruby) will convert it to ASCII instead of UTF-8
    @_post_fast_hide = proc {|buf,p,should_hide| buf << md1 << p.id.to_s << md2 << (should_hide ? iftrue : iffalse) << md3}

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
    cu = cu.login if cu

    @_should_highlight = proc {|l| settings_allow && (l == cu)}
  end

  def time_for_header(time,tz)
    tz.utc_to_local(time).strftime("%d.%m.%Y %H:%M")
  end

  # Casted after the tree is printed.  Changes the class of the span the current post's header is wrapped, so that it looks differently
  def post_span_replace(post,tree_string)
    post.nil? ? tree_string : tree_string.gsub(/<!--post:#{post.id}--><span class="post-oneline">/,%Q(<!--post:#{post.id}--><span class="this-post-oneline">))
  end

  # Print raw html (no ERB or HAML!) for a line of this post.  User view settings are ignored for now
  def fast_print(post, tz, buf = '')
    # We'll use string as a "StringBuffer", appending to a mutable string instead of concatenation

    # Some users may view deleted posts (if they're privileged enough).
    # See the closing tag the end of the function
    buf << %Q(<span class="post-deleted">) if post.deleted

    # Post title (link or plain, depending on whether it's the current post)
    # Warning!  This comment with a post's ID is used to replace the span's class to match the post.  See post_span_replace function.
    buf << %Q(<!--post:#{post.id}--><span class="post-oneline">)
    # This already prints to the buf!  Do not append, or your memory will blow!
    fast_link[buf,post]
    buf << %Q(</span>)
    if post.empty_body?
      buf << ' (-)'
    else
      buf << ' (+)'
    end
    # (url)/(pic) marks
    post.marks.each do |mark|
      buf << ' <span class="post-mark">(' << mark << ")</span>"
    end
    # post clicks
    if post.clicks != 0 && post.clicks != '0'
      buf << ' <span class="post-clicks">(' << post.clicks.to_s  << ")</span>"
    end
    buf << ' - '
    # Due to the speed concerns, we use user_login here instead of user.login, so we don't need to load users
    if this_login = post.user_login
      # Highlight message, if necessary
      if should_highlight[this_login]
        buf << %Q(<span class="post-self">)
      else
        buf << %Q(<span class="post-user">)
      end
      fast_user[buf,this_login]
      buf << %Q(</span>)
    else
      buf << %Q(<span class="post-unreg">) << (post.unreg_name || "NIL") << %Q(</span>)
    end
    buf << " (#{post.host}) "
    buf << %Q(<span class="post-timestamp">) << time_for_header(post.created_at,tz) << %Q(</span>)

    # See the opening tag the end of the function
    buf << %Q(</span>) if post.deleted
  end

  def fast_showhide(post,tree,thread_hides,buf = '')
    # Post hidden mark and hide/show modifier
    # NOTE: the attrs to hidden_by are ignored for the FasterPost, but they're left for compatibility with the usual Posts.
    # For FasterPost, :user => current_user has already been applied in the fetching sql, so we do not specify it here
    hidden = post.hidden_by?(:user => current_user, :thread_hides => thread_hides, :show_all => @show_all_posts) 
    # Unfortunately, we can't use permissions here (until we optimize them)
    #if permitted_to? :toggle_showhide, :posts
    buf << ' '
    fast_hide_prepared = fast_hide {[t("Show subtree"), t("Hide subtree")]}
    if tree[post.id] && !tree[post.id].empty?
      if hidden 
        fast_hide_prepared[buf,post,true]
      else
        fast_hide_prepared[buf,post,false]
      end
    end
    return !hidden
  end

  # This yields HTML code for the tree that starts with the +start+ post, but doesn't highlight the current post.
  def fast_generic_tree(buf,tree,start,hides = {}, tz = DEFAULT_TZ)
    # If start is nil, then we're printing the index, and skip the post itself.
    unless_deleted(start){fast_print(start,tz,buf)} if start
    # Show if post is hidden, and display the toggle
    post_shown = fast_showhide(start,tree,hides,buf)
    unless post_shown
      buf << ' ' << t('Hidden')
      return buf
    end
    kids = tree[start.id]
    return buf unless kids
    buf << %Q(<ul>\n)
    kids.each do |child|
      unless_deleted child do
        buf << %Q(<li>)
        fast_generic_tree(buf,tree,child,hides,tz)
        buf << %Q(</li>\n)
      end
    end
    buf << %Q(</ul>\n)
  end

  def fast_tree(buf,tree,start,hides = {}, tz = DEFAULT_TZ)
    prepped = fast_generic_tree(buf,tree,start,hides,tz)
    post_span_replace(@post,prepped)
  end

  # A convenience helper to get a cache-stamp of something.  This "something" usually has a modification time accessible via "updated_at" and an id.
  def key_of(something)
    "#{something.id}@#{something.updated_at}"
  end

  # Returns the cached HTML for the tree of the "thr" thread.  Accounts for @post.
  def fast_tree_cache(thr,buf,start,presentation)
    # The wat a thread is displayed depends on many factors.
    # - thread itself (identified by id and modification time);
    # - the user itself (his or her name may be colored), identified by id *and* modification time (think altnames!).  This implies that its roles are already accounted for.
    # - the user's presentation (identified by its id and mtime)
    # - the current thread (this is fixed by a kludgy regexp).
    # - global configuration of the site (modification time of it);
    # x user's timezone (this is accounted for in the presentations)
    # x what post we are showing (it's @post).  This will be replaces with a regexp-like kludge.
    # TODO: Later, these rules may be replaced with whether the user has touched the thread, but it's fast enough now
    thread_key = key_of thr
    user_key = current_user ? key_of(current_user) : 'guest'
    presentation_key = key_of presentation
    cache_key = "tree-thread:#{thread_key}-user:#{user_key}-view:#{presentation_key}-global:#{config_mtime}"
    logger.debug "Tree for key: '#{cache_key}'"
    # Get the prepared thread to incur the current post into it
    prepped = Rails.cache.fetch(cache_key, :expires_in => THREAD_CACHE_TIME) do
      logger.debug "Tree for key: '#{cache_key}' miss!"
      fast_generic_tree(buf,thr.build_subtree_fast,thr.fast_head,thr.hides_fast,presentation.tz)
    end
    # Replace current post
    post_span_replace(@post,prepped)
  end

end
