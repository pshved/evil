xml.instruct! :xml, :version => "1.0" 
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "Latest #{Configurable[:site_title]} Posts"
    xml.description "Latest messages posted onto the #{Configurable[:site_title]} board"
    xml.link latest_posts_url

    for post in @posts
      xml.item do
        xml.title post.title
        xml.description post.filtered_body
        xml.pubDate post.created_at.to_s(:rfc822)
        xml.link post_url(post)
        xml.guid post_url(post)
      end
    end
  end
end

