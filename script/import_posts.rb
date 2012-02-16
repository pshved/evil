#!/usr/bin/ruby
# coding: utf-8
# Posts importer

require 'net/http'
require 'xml'

HEAD_WINDOW = 10
BOARD_URL = 'http://x.mipt.cc/?read='

queue = []

# Populates the query.  Constructs it from the posts that are not finished, and adds some more posts to the end of the queue
def populate
  last = Import.where('status <> "finished"').order('post_id ASC').all.map {|imp| imp.post_id}
  if last.length < HEAD_WINDOW
    max_n = last.last || Import.maximum('post_id') || 0
    puts "TIMES: #{HEAD_WINDOW - last.length}"
    (HEAD_WINDOW - last.length).times do
      max_n += 1
      last << max_n
    end
  end
    puts "RL: #{last.inspect}"
  last
end

def make_post(params)
  # First, let's load a matching post, if any
  p = Posts.find_by_back(params[:id])
  p ||= Posts.new
  # Now, set its attrs
  p.assign_attributes(:user => nil, :unreg_name => params[:login], :host => (params[:host] || 'localhost') )
  p.text_container = TextContainer.make(params[:title],params[:body])
  # Set up HTML (raw) filter, so that boardtags are not applied
  p.text_container.filter = :html
  # Backward compatibility
  p.back = params[:id]
  # Parent is the ID as of the forum being imported...
  parent_id = params[:parent_id]
  parent_id &&= Posts.find_by_back(parent_id)
  so = p.attach_to(parent_id)
  return so, p
end

$conv = Encoding::Converter.new('CP1251','UTF-8')
def try_download_post(post_id)
  post_url = "#{BOARD_URL}#{post_id}"
  uri = URI(post_url)
  suc = Net::HTTP.get(uri)
  s = $conv.convert suc
  #puts "#{post_id} : #{s}"
  # Ok, let's convert
  puts "\n\nConverting #{post_id}...\n"
  doc = XML::HTMLParser.string(suc, :options =>  XML::HTMLParser::Options::RECOVER).parse
  # Find the title
  title = doc.find(%Q(/html/body/div[@align="CENTER"]/big))[1].inner_xml
  title = title.slice(0..95)
  puts "Title: #{title}"
  # Find the body (if any)
  body = doc.find(%Q(//div[@class="body"]))[0].inner_xml
  unless body.blank?
    puts "Body: #{body}"
  else
    puts "Body: EMPTY"
    # We can't set body as nil!
    body = ''
  end
  # Find the parent.  First, locate the post's node in the tree
  this_node = doc.find(%Q(//b/span[@class="subject"]))[0]
  parent_node = this_node.parent.parent.parent.parent.prev.attributes['id']
  if parent_node
    parent_node =~ /m([0-9]+)/
    parent_node = $1.to_i
  end
  puts "Parent of #{post_id} is #{parent_node.inspect}"

  # Reg name
  # xml instead of html!
  unreg_name = doc.find(%Q(/html/body/div[@align="CENTER"]/span[@class="unreg"]))[0]
  unreg_name = doc.find(%Q(/html/body/div[@align="CENTER"]/a[@class="nn"]))[0] unless unreg_name

  unreg_name = unreg_name.inner_xml

  # Timestamp and host
  ts_and_host_str = this_node.parent.parent.parent.find(%Q(span[@class="reg" or @class="unr"]))[0].next
  tahs = ts_and_host_str.content.inspect

  puts "TAHS: #{tahs}"

  tahs =~ /\((.*)\) — (.*)/ or raise "Can't match regexp with '#{tahs}'"

  host = $1
  timestamp = DEFAULT_TZ.local_to_utc(DateTime.strptime($2, '%d/%m/%Y %H:%M'))

  # Now compose and convert the post
  to_save, post = make_post(:parent_id => parent_node, :title => title, :body => body, :id => post_id, :login => unreg_name, :host => host)
  begin
    to_save.save!
  rescue => e
    puts to_save.errors.full_messages
    raise e
  end

  # After we have created the records, fix their creation timestamp
  post.created_at = timestamp
  to_save.created_at = timestamp

  return to_save, post
end

# Populate the initial queue
# queue the ten most recent posts that are not downloaded

queue = populate

while true
  if queue.empty?
    Kernel.sleep(1)
    queue = populate
  else
    imp = nil
    next_id = nil
    Import.transaction do
      next_id = queue.shift
      imp = Import.find_or_create_by_post_id(next_id)
      if imp.status == :queued
        imp.status = :downloading
        imp.save
      else
        skip = true
      end
    end
    if imp.status == :downloading
      begin
        to_save, post = try_download_post(next_id)
        to_save.save
        imp.status = :finished
        imp.save
      rescue => e
        puts "Download failure: #{e}!"
        imp.status = :queued
        imp.save
      end
    end
    # Sleep to not make us as flooders
    Kernel.sleep(1)
  end
end

