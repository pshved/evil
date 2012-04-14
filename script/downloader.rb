#!/usr/bin/ruby
# coding: utf-8

# Posts downloader
# Downloads pages from a board, and sends them to the server via API calls.  The purpose of this script is not to parse content, but to send individual posts to the evil web server for it to parse and properly import them.  This will require a certain degree of parsing though.

require 'rubygems'
require 'fileutils'
require 'hpricot'
require 'logger'
require 'net/http'
require 'optparse'
#require 'xml'

$log = Logger.new(STDOUT)
$log.level = Logger::INFO

options = {:api => 'xmlfp', :from => 1}
OptionParser.new do |opts|
  opts.banner = "Usage: ./download.rb [options]"

  opts.on("-a API", "--api", "What download interface to use.  Available: xmlfp") do |v|
    options[:api] = v
  end

  opts.on("-f FROM", "--from", Integer, "The start post number") do |v|
    options[:start] = v
  end

  opts.on("-d DIR", "--cache-dir", "Where to cache the downloaded files") do |v|
    options[:cache_dir] = v
  end
end.parse!

url = ARGV[0].dup

class NullStrategy
  def initialize(initial)
    @current = initial
  end
  # Returns the move the strategy advises to make
  attr_reader :current
  # Updates current and returns the strategy for the next move
  def move(_)
    self
  end
  # Debug-prints the state
  def print
    "<NONE>"
  end
  # Some strategies allow you to prevent an attempt to make a move if it's useless.  The attempt is encoded as a block.  Returns false if the attempt was not successful (just like it resulted in false if it was actually performed).
  def peek_or
    yield
  end
end

class DownStrategy < NullStrategy
  def move(was_success)
    @current -= 1 if was_success
    if @current <= 0
      # Do not iterate anymore
      NullStrategy.new(@current)
    else
      # Continue
      self
    end
  end
  def print
    "<DOWN from #{@current}>"
  end
end

# Goes up step-by-step, returns another strategy at failure (or just sleeps for 10 seconds if unspecified)
class UpStrategy < NullStrategy
  attr_accessor :when_we_reach_fail
  def initialize(initial, when_we_reach_fail = nil)
    super(initial)
    @when_we_reach_fail = when_we_reach_fail || proc { sleep(10); self }
  end
  def move(was_success)
    if was_success
      @current += 1
      self
    else
      # A special case: if when_we_reach_fail returns nil, we keep the strategy
      @when_we_reach_fail[@current] || self
    end
  end
  def print
    "<UP from #{@current}>"
  end
end

# Goes up step-by-step, stops at the prespecified number (max), then turns back.
class LimitedUpStrategy < NullStrategy
  #attr_accessor :
  def initialize(initial, max, when_we_reach_fail = nil)
    super(initial)
    @upper = max || initial
    @when_we_reach_fail = when_we_reach_fail || proc { sleep(10); self }
  end
  def move(was_success)
    # If we have downloaded everything, return the next strategy
    if @current > @upper
      @when_we_reach_fail[@current] || self
    else
      # We only repeat the query if server is down.  Otherwise, we keep going regardless of whether the post actually exists
      @current += 1 unless was_success.nil?
      self
    end
  end
  def print
    "<LIM-UP from #{@current} to #{@upper}>"
  end
  def peek_or
    (@current <= @upper) ? yield : false
  end
end

# Iterates over several strategies in the round-robin fashion, discarding those that reach quiesence.
class AlterStrategy < NullStrategy
  def initialize(*strategies)
    @strategies = strategies
    raise "Specify at least one strategy, please!" if @strategies.length <= 0
    @i = 0
  end

  def move(success)
    i = @i
    @strategies[i] = @strategies[i].move(success)
    unless @strategies[i]
      @strategies.delete_at(i)
    end
    # If there's no more strategies left, fold self as well
    return NullStrategy.new if @strategies.length == 0
    # ...besides, we'd hit division by zero here
    @i = (i + 1).modulo @strategies.length
    self
  end

  def current
    @strategies[@i].current
  end

  def print
    r = "Combine #{@strategies.length}: "
    @strategies.each_with_index do |s,i|
      r << ((i == @i) ? "**#{i}**" : "#{i}:")
      r << s.print << '  '
    end
    r
  end

  def peek_or(&b)
    @strategies[@i].peek_or(&b)
  end
end

class Downloader
  attr_accessor :strategy
  def initialize(opts = {})
    @base_path = opts[:base_path] or raise "Specify base_path please!"
    @base_path.gsub!(/\/*$/,'')
    current = opts[:start]
    current = 1 if !current || current <= 0

    @strategy = AlterStrategy.new(UpStrategy.new(current), DownStrategy.new(current - 1))

    # Cache, if any
    @cache_dir = opts[:cache_dir]
  end

  def current
    @strategy.current
  end

  def test
    Net::HTTP.get_response(uri) rescue false
  end

  def work
    $log.info "Work: @current=#{current}, state=#{@strategy.print}"
    r = @strategy.peek_or {download}
    @strategy = @strategy.move(r)
    $log.debug "Work: next @current=#{current}, state=#{@strategy.print}"
    r
  end

  protected
  def uri
    URI(@base_path)
  end

  # Get from cache or download
  def cache(key)
    return yield unless @cache_dir
    target = File.join(@cache_dir,key)

    if File.exists? target
      @last_was_cached = true
      return IO.read(target)
    end
    @last_was_cached = false

    result = yield

    # Only cache successful downloads of actual posts
    if result
      # Write then move, because we don't want incomplete files in our cache!
      File.open("#{target}.tmp","w") {|f| f.write result}
      FileUtils.move("#{target}.tmp",target)
    end

    result
  end

  public
  def last_was_cached?
    @last_was_cached
  end

end

# Thanks to Tom Mortel
def y_combinator(&f)
  lambda {|x| x[x] } [
    lambda {|maker| lambda {|*args| f[maker[maker]][*args] }}
  ]
end

class XmlfpDownloader < Downloader
  def initialize(opts = {})
    super(opts)
    # We should re-program our strategy so that it queries last_message_id when it finds a nonexistent post
    get_last_message_when_reach_up = y_combinator {|recurse| proc do |current|
      # Check last message ID
      begin
        $log.debug "Checking last_message_id at #{make_last_messge_id_url}"
        rsp = Net::HTTP.get_response(URI(make_last_messge_id_url))
        body = rsp.body
        doc = Hpricot(body)
        # Hpricot is "liberal" enough to return empty strings if the element was not found
        status = doc.search(%Q(/lastMessageNumber)).inner_text.to_i
        $log.debug %Q(Status found by /lastMessageNumber is '#{status}')
        # Now check if we have anything new
        if status <= current
          # No, nothing new, wait for more messages to appear
          sleep 2
        end
        # In any case, our next strategy will be checking the lastMessageNumber with the current function, and trying to reach the limit.
        LimitedUpStrategy.new(current,status,recurse)
      rescue Net::HTTPBadResponse
        sleep 10
        retry
      end
    end}

    @strategy = AlterStrategy.new(UpStrategy.new(current, get_last_message_when_reach_up), DownStrategy.new(current - 1))

  end

  def download
    begin
      cache "#{current}.html" do
        $log.debug "Downloading #{make_url}"
        rsp = Net::HTTP.get_response(URI(make_url))
        body = rsp.body
        $log.debug "Response: #{body ? body[0..10] : body.inspect}..."

        if body =~ /Ошибочный запрос на действие/
          $log.debug "Response matches bad regexp, retry"
          false
        else
          doc = Hpricot(body)
          # Hpricot is "liberal" enough to return empty strings if the element was not found
          status = doc.search(%Q(//message[@id="#{current}"]/status)).inner_html
          $log.debug %Q(Status found by //message[@id="#{current}"]/status is '#{status}')

          if status == 'not_exists'
            # Serwer was OK, so return false instead of nil
            false
          else
            body
          end
        end
      end
    rescue Net::HTTPBadResponse
      # Couldn't connect.  Return nil instead of false
      nil
    end
  end

  def make_url
    %Q(#{@base_path}/?xmlfpread=#{current})
  end

  def make_last_messge_id_url
    %Q(#{@base_path}/?xmlfplast)
  end
end

class DownloaderFactory
  def self.make(kind, opts = {})
    case kind
    when 'xmlfp'
      XmlfpDownloader.new(opts)
    else
      raise "Unknown strategy: #{kind}"
    end
  end
end

options[:base_path] = url

$log.debug "Start with opts=#{options.inspect}"

dler = DownloaderFactory.make(options[:api],options)

puts dler.test.inspect

while true
  $log.debug "Loop"
  last_dl = dler.current
  r = dler.work
  $log.debug "Result: #{r.inspect}"
  if r
    $log.info "Downloaded post #{last_dl} entitled #{Hpricot(r).search(%Q(//message[@id="#{last_dl}"]/content/title)).inner_text}"
  else
    $log.info "Could not download post #{last_dl}"
  end
  sleep(2) unless dler.last_was_cached?
end


