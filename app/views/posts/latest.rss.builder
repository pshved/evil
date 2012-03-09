xml.instruct! :xml, :version => "1.0" 
xml.rss :version => "2.0" do
  xml.channel do
    xml.title ta('xml.title',:post, :site_title => Configurable[:site_title])
    xml.description ta('xml.description',:post,:site_title => Configurable[:site_title])
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

