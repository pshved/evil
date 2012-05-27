require 'xml'

# Update +context+ data with the marks data.  This is used for imported nodes
def calculate_marks_for_html(text,context)
  # Don't try to parse blank text
  return if text.blank?
  # skip marks calculation if context is nil--we must have already calculated the marks
  return if context.nil?

  begin
    doc = XML::HTMLParser.string(text, :options => XML::HTMLParser::Options::RECOVER).parse
  rescue
    $stderr.puts "Couldn't parse!"
    return
  end

  unless doc.find(%Q(//a)).empty?
    context.sign[:url] = true
  end
  unless doc.find(%Q(//iframe[@class="youtube-player"])).empty?
    context.sign[:vid] = true
  end
  unless doc.find(%Q(//img)).empty?
    context.sign[:pic] = true
  end
end

