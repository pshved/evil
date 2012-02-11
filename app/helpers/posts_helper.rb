# coding: utf-8
# As we work with strings here, we should set encoding for them
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

  # Print raw html (no ERB or HAML!) for a line of this post.  User view settings are ignored for now
  def fast_print(post, buf = '')
    # We'll use string as a "StringBuffer", appending to a mutable string instead of concatenation

    # Post title (link or plain, depending on whether it's the current post)
    # We strip whitespace from the post's title
    post_title = post.title.strip
    if @post && (post.id == @post.id)
      buf << %Q(<span class="this-post-oneline">) << h(post_title) << %Q(</span>)
    else
      buf << %Q(<span class="post-oneline">)
      fast_link[buf,post]
      buf << %Q(</span>)
    end
    buf << ' '
    if post.empty_body?
      buf << '(-)'
    else
      buf << '(+)'
    end
    # (url)/(pic) marks
    post.marks.each do |mark|
      buf << '<span class="post-mark">(' << mark << ")</span> "
    end
    # post clicks
    if post.clicks != 0
      buf << '<span class="post-clicks">(' << post.clicks  << ")</span>"
    end
    buf << ' - '
    # Due to the speed concerns, we use user_login here instead of user.login, so we don't need to load users
    if post.user_login
      buf << %Q(<span class="post-user">)
      fast_user[buf,post.user_login]
      buf << %Q(</span>)
    else
      buf << %Q(<span class="post-unreg">) << (post.unreg_name || "NIL") << %Q(</span>)
    end
    buf << " (#{post.host}) "
    buf << %Q(<span class="post-timestamp">) << post.created_at.to_s << %Q(</span>)
    #-# Post hidden mark and hide/show modifier
    #-hidden = post.hidden_by?(:user => current_user, :thread_hides => thr.hides)
    #- if permitted_to? :toggle_showhide, :posts
      #- if hidden
        #=link_to t("Show subtree"), toggle_showhide_post_path(post)
      #- else
        #=link_to t("Hide subtree"), toggle_showhide_post_path(post)
    #We only hide posts in the index, hence @show_all_posts condition!

    buf
  end

  def fast_tree(buf,tree,start)
    # If start is nil, then we're printing the index, and skip the post itself.
    fast_print(start,buf) if start
    kids = tree[start.id]
    return buf unless kids
    buf << %Q(<ul>\n)
    kids.each do |child|
      buf << %Q(<li>)
      fast_tree(buf,tree,child)
      buf << %Q(</li>\n)
    end
    buf << %Q(</ul>\n)
  end

end
