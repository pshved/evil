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
require 'json'

$log = Logger.new(STDOUT)

options = {:api => 'xmlfp', :from => 1, :target => nil, :enc => 'CP1251'}
OptionParser.new do |opts|
  opts.banner = "Usage: ./download.rb [options]"

  opts.on("-a API", "--api", "What download interface to use.  Available: xmlfp") do |v|
    options[:api] = v
  end

  opts.on("-f FROM", "--from", Integer, "The start post number.  This post is not downloaded, only the next one is.") do |v|
    options[:start] = v
  end

  opts.on("-t TO", "--to", Integer, "The end post number.  Should be greater than -f.") do |v|
    options[:end] = v
  end

  opts.on("-d DIR", "--cache-dir", "Where to cache the downloaded files") do |v|
    options[:cache_dir] = v
  end

  opts.on("-r TARGET", "--recipient", "Where to send the downloaded files") do |v|
    options[:target] = v
  end

  opts.on("-i INTERVAL", "--interval", "Where to query the request interval") do |v|
    options[:interval] = v
  end

  opts.on("-e ENCODING", "--encoding", "The encoding the forum is in") do |v|
    options[:enc] = v
  end

  opts.on("-v", "--verbosity", "Be verbose") do |v|
    options[:verbose] = true
  end

  opts.on("-n", "--dry-run", "Do not POST, only download") do |v|
    options[:dry] = true
  end
end.parse!

url = ARGV[0].dup

$log.level = Logger::INFO
$log.level = Logger::DEBUG if options[:verbose]

###############################################
#  Utils
###############################################

def lap(stuff, wtf = '')
  $log.debug "#{wtf} #{stuff.inspect}"
  stuff
end

###############################################
#  Downloading section
###############################################

class DummyIntervalRequestor
  DEFAULT_TIMEOUT = 30

  def initialize(timeout = DEFAULT_TIMEOUT)
    @timeout = timeout
    @pipe_r_from, @pipe_w_to = IO.pipe
    @child_thread = Thread.new do
      while true
        $log.debug "Run next_interval"
        new_interval = next_interval
        if new_interval && new_interval != @timeout
          $log.debug "Will print next_interval: #{new_interval}"
          @timeout = new_interval
          @pipe_w_to.puts @timeout
        else
          $log.debug "Will NOT print next_interval: #{new_interval.inspect} and #{@timeout.inspect}"
        end
      end
    end
  end

  def read_pipe
    @pipe_r_from
  end

  def next_interval
    sleep DEFAULT_TIMEOUT
    @timeout
  end

  def reconsider_timeout
    new_timeout_s = read_pipe.gets
    $log.debug "Pipe is ready, read #{new_timeout_s}"
    @timeout = new_timeout_s.to_i || DEFAULT_TIMEOUT
  end

  # Do not confuse it with next_interval: timeout requests the current one, and next_interval requests the next one from an external source
  attr_reader :timeout

  # Just waits for the recorded timeout
  def just_wait(pause = nil)
    $log.debug "JUST SLEEP: #{pause || timeout}"
    sleep(pause || timeout)
  end
end

# Retry doing the block infinitely, with pause "pause" until it doesn't throw an exception
def inf_retry(pause_sec = 30)
  begin
    yield
  rescue => e
    $log.debug "Connection error #{e}.  Sleep #{pause_sec} sec."
    sleep pause_sec
    retry
  end
end

class WebDownloader
  PAUSE = 10
  def initialize(wait_breaker = DummyIntervalRequestor.new)
    @wait_breaker = wait_breaker
  end

  # Download page, retrying on all errors
  def download(url, pause_before = nil, pause_retry = 30)
    if pause_before
      $log.debug "Sleeping the fixed #{pause_before} sec via select"
      wait_for_interval(pause_before)
    else
      pause_sec = @wait_breaker.timeout
      $log.debug "Sleeping the timer's #{pause_sec} sec via select"
      wait_for_interval(pause_sec)
    end
    # Now download
    $log.debug "Downloading from #{url}"
    rsp = inf_retry(pause_retry) {Net::HTTP.get_response(URI(url))}
    body = rsp.body
    $log.debug "Got response '#{body}'"
    body
  end

  # Interval waiting
  def wait_for_interval(timeout)
    $log.debug "Launch select with to #{timeout} and #{@wait_breaker.read_pipe}"
    if select_results = IO.select([@wait_breaker.read_pipe],nil,nil,timeout)
      # Something happened, not just timeout
      @wait_breaker.reconsider_timeout
    else
      $log.debug "Timeout #{timeout} reached"
    end
  end

  # Just waits for the recorded timeout (and breaks if necessary)
  def just_wait(pause = nil)
    wait_for_interval(pause || timeout)
  end
end

###############################################
#  Strategy section
###############################################

# Move classes
Move = Hash
BoardResponse = Hash

class NoMoves < Exception
end

class NullStrategy
  def initialize(initial)
    @current = initial
  end
  # Returns the move the strategy advises to make
  attr_reader :current
  # Get a response to the move "peek" returns, and return the strategy that will yield the further game
  def move(_)
    raise NoMoves.new
    self
  end
  # Debug-prints the state
  def print
    "<NONE>"
  end
  # Check what the next move would be
  def peek
    nil
  end
end

# Returns if the range was downloaded incomletely, and if it was, returns the last downloaded post number plus one (i.e. the first post number that is suspect to be not existant)
def incomplete_range(request,response)
  q = request[:range]
  p = response[:range]
  if p.length > 0
    # Something has been returned
    (p.max >= q.max) ? nil : (p.max+1)
  else
    # Response is empty: nothing has been downloaded
    q.min
  end
end

# Not fixed
class LimitedDownStrategy < NullStrategy
  def initialize(initial, lowest, step = 1)
    super(initial)
    @pause = WebDownloader::PAUSE # A smaller pause between range downloads
    @step = step
    @lowest = lowest
  end
  def move(response)
    # We don't really care about the response, we only check if the range of posts to download is exhausted.
    next_move = peek[:range].min - 1
    if next_move < @lowest
      # Do not iterate anymore
      NullStrategy.new(next_move)
    else
      @current = next_move
      # Continue iterations
      self
    end
  end
  def peek
    {:range => (([@current - @step + 1, @lowest].max)..@current), :pause => @pause}
  end
  def print
    "<DOWN from #{@current} to #{@lowest} with step #{@step}>"
  end
end

# Not fixed
class DownStrategy < LimitedDownStrategy
  def initialize(initial, step = 1)
    super(initial,1,step)
  end
end

# Being fixed
# Goes up step-by-step, returns another strategy at failure (or just sleeps for 10 seconds if unspecified)
class UpStrategy < NullStrategy
  attr_accessor :when_we_reach_fail
  def initialize(initial, when_we_reach_fail = nil, step = 1)
    super(initial)
    @step = step || 1
    @pause = WebDownloader::PAUSE
    @when_we_reach_fail = when_we_reach_fail || proc { sleep(10); self }
  end
  def move(response)
    next_try = incomplete_range(peek,response)
    if next_try == peek[:range].min
      # A special case: if when_we_reach_fail returns nil, we keep the strategy
      @when_we_reach_fail[next_try] || self
    elsif next_try
      @current = next_try
      self
    else
      @current += @step
      self
    end
  end
  def peek
    # We make a smaller pause if we're just downloading, not waiting
    {:range => (@current..(@current+@step-1)), :pause => @pause}
  end
  def print
    "<UP from #{@current} with step #{@step}>"
  end
end

# Goes up step-by-step, stops at the prespecified number (max), then returns a strategy from the callback if any
class LimitedUpStrategy < NullStrategy
  def initialize(initial, max, step = 1, when_we_reach_fail = nil)
    super(initial)
    @pause = WebDownloader::PAUSE # A smaller pause between range downloads
    @upper = max || initial
    @when_we_reach_fail = when_we_reach_fail || proc { sleep(10); self }
    @step = step || 1
  end
  def move(response)
    # We don't really care about the response, we only check if the range of posts to download is exhausted.
    next_move = peek[:range].max + 1
    if next_move > @upper
      # If we have downloaded everything, return the next strategy, supplying the next message as the starting point
      @when_we_reach_fail[@upper+1] || self
    else
      @current = next_move
      self
    end
  end
  def print
    "<LIM-UP from #{@current} to #{@upper} with step #{@step}>"
  end
  def peek
    {:range => (@current..([@current + @step - 1, @upper].min)), :pause => @pause}
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
    if @strategies[i].nil? || (@strategies[i].class == NullStrategy)
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

  def last_success
    @strategies[@i].last_success
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

###############################################
#  Generic board downloader classes
###############################################

# Downloads posts from a board
class BoardDownloader
  # Gets posts in the range specified, making a pause before (if pause is nil, then it's up to the downloader)
  def get_posts(r,pause = nil)
    return []
  end

  # Gets the last message id on the board
  def get_last_message_id
    nil
  end
end

# A mock downloading engine, useful in tests.  Initialized with an array of pairs [t,n], where t is the time when the n-th message is posted (n can also be a range object).  The time t is counted from the start.
class MockDownloader < BoardDownloader
  def initialize(timeposts,timeouter)
    @sequence = timeposts.sort {|a,b| a[0] <=> b[0] }
    @posts = []
    @start_time = Time.now
    commit_sequence_until @start_time
    @timeouter = timeouter
  end

  def get_posts(r,pause = nil)
    @timeouter.just_wait(pause)
    commit_sequence_until
    @posts.select{|p| r.include? p }.inject({}) {|acc,p| acc[p]=p; acc}
  end

  def get_last_message_id(pause = nil)
    @timeouter.just_wait(pause)
    commit_sequence_until
    @posts.max
  end

  protected
  def commit_sequence_until(time = Time.now)
    while (x = @sequence.first) && (@start_time + x[0] < time)
      _,x = @sequence.shift
      x = [x] if x.is_a? Integer
      $log.debug "Adding posts: #{x.inspect}"
      x.each {|p| @posts << p}
    end
    $log.info "Max post now is: #{@posts.max}"
  end
end

###############################################
#  XMLFP downloading engine
###############################################

# Each 2 seconds, request json api, and read 'timeout' from there.
class JSONIntervalRequestor < DummyIntervalRequestor
  def initialize(addr,timeout)
    super(timeout)
    @json_request_addr = addr
  end

  def next_interval
    # Call json apii
    to = 2
    begin
      $log.debug "Checking interval at #{@json_request_addr}"
      rsp = inf_retry {Net::HTTP.get_response(URI(@json_request_addr))}
      body = rsp.body
      $log.debug "Got response '#{body}'"
      to = JSON(rsp.body)['timeout'].to_i
      $log.debug "Got timeout '#{to}'"
      (to < 5)? 5 : to
    rescue => e
      $stderr.print "Exception #{e}"
      sleep 10
      retry
    end
    sleep 2
    to
  end
end

class XmlfpDownloader < BoardDownloader
  DEFAULT_PAUSE_BETWEEN_DL = 100
  def initialize(board_url, timeouter)
    @range_url = "#{board_url}/?xmlfpindex"
    @last_message_url = "#{board_url}/?xmlfplast"

    @dl = WebDownloader.new(timeouter)
  end

  def make_url(r1,r2)
    %Q(#{@range_url}&from=#{r1}&to=#{r2})
  end
  def make_last_messge_id_url
    %Q(#{@last_message_url})
  end

  def get_posts(range,pause = nil)
    $log.info "Getting range from #{range.first} to #{range.last}"
    $log.debug "Downloading #{make_url(range.first,range.last)}"
    body = @dl.download(make_url(range.first,range.last),pause)
    $log.debug "Response: #{body ? body[0..10] : body.inspect}..."

    doc = Hpricot(body)
    # Hpricot is "liberal" enough to return empty strings if the element was not found
    range.inject({}) do |acc,current|
      status = doc.search(%Q(//message[@id="#{current}"]/status)).inner_html
      $log.debug %Q(Status found by //message[@id="#{current}"]/status is '#{status}')

      acc[current] = body unless status == 'not_exists'
      acc
    end
  end

  def get_last_message_id(pause = nil)
    $log.info "Checking last_message_id at #{make_last_messge_id_url}"
    body = @dl.download(make_last_messge_id_url,pause)
    doc = Hpricot(body)
    # Hpricot is "liberal" enough to return empty strings if the element was not found
    status = doc.search(%Q(/lastMessageNumber)).inner_text.to_i
    $log.debug %Q(Status found by /lastMessageNumber is '#{status}')
    status.to_i
  end

end

class Fetcher
end

class XmlfpFetcher < Fetcher
  MAX_STEP = 100
  attr_accessor :strategy
  def initialize(opts = {})
    # Prepare a web accessor
    @base_path = opts[:base_path] or raise "Specify base_path please!"
    @base_path.gsub!(/\/*$/,'')

    interval_requestor = JSONIntervalRequestor.new(opts[:interval],31)
    @dl = XmlfpDownloader.new(@base_path,interval_requestor)
    # To test the strategies, mock the downloader by uncommenting this:
    #@dl = MockDownloader.new([[0,(1..5000)], [5,5001], [7,5002], [13,5003], [31,5004], [52,5005], [123,5006],[124,5007]],interval_requestor)

    current = opts[:start]
    current = 1 if !current || current <= 0

    # We should re-program our strategy so that it queries last_message_id when it finds a nonexistent post
    get_last_message_when_reach_up = y_combinator {|recurse| proc do |current|
      # Check last message ID until it's at least as big as what we'd like to get
      $log.info "Starting to wait for more messages with less heavy queueing; will start from #{current} asap"
      last_id = @dl.get_last_message_id
      while last_id < current
        last_id = @dl.get_last_message_id
      end
      $log.debug "Switching to LimitedUp"
      # As soon as we got the last message id greater than this one, download them and start waiting again
      LimitedUpStrategy.new(current,last_id,MAX_STEP,recurse)
    end}


    s = opts[:start]
    e = opts[:end]
    # If e is not specified, then we download upwards only starting at s.  Otherwise, we download upwards or downwards, whichever fits.

    # For test, we'll try a simple strategy

    if e && e >= s
      @strategy = LimitedUpStrategy.new(s,e,MAX_STEP)
    elsif e && e < s
      @strategy = LimitedDownStrategy.new(s - 1,e,MAX_STEP)
    else
      @strategy = UpStrategy.new(s, get_last_message_when_reach_up,MAX_STEP)
    end

  end

  def test
    Net::HTTP.get_response(uri) rescue false
  end

  def work
    $log.info "Work: state=#{@strategy.print}"
    move = @strategy.peek
    # Let our "adversary" move...
    msgs = @dl.get_posts(move[:range],move[:pause])
    response = {:messages => msgs, :range => msgs.keys.map(&:to_i).sort}
    $log.debug "Response to move=#{move.inspect} is #{response.inspect}"
    # And set the next strategy
    @strategy = @strategy.move(response)

    $log.debug "After move: state=#{@strategy.print}"
    response
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
      return Marshal.load(IO.read(target))
    end
    @last_was_cached = false

    result = yield

    # Only cache successful downloads of actual posts
    if result
      # Write then move, because we don't want incomplete files in our cache!
      File.open("#{target}.tmp","w") {|f| f.write Marshal.dump(result)}
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

class FetcherFactory
  def self.make(kind, opts = {})
    case kind
    when 'xmlfp'
      XmlfpFetcher.new(opts)
    else
      raise "Unknown strategy: #{kind}"
    end
  end
end

options[:base_path] = url

$log.debug "Start with opts=#{options.inspect}"

dler = FetcherFactory.make(options[:api],options)

puts dler.test.inspect

while true
  $log.debug "Loop"
  r = dler.work
  if r
    $log.debug "Result: #{r[:range].inspect}"
    downloaded_ids = r[:range]
    if downloaded_ids.empty?
      $log.info "Nothing was downloaded, trying again"
      next
    end
    r1, r2 = downloaded_ids.first, downloaded_ids.last
    $log.info "Range from #{r1} to #{r2}"
    # Send post to the target
    if targ = options[:target] && (!options[:dry])
      inf_retry(10){
      Net::HTTP.post_form(URI(options[:target]), {
        :source_url => url,
        :post_start => r1,
        :post_end => r2,
        :api => options[:api],
        # They're all equal anyway... for now.
        :page => r[:messages][r1],
        :enc => options[:enc],
      })}
    elsif options[:dry]
      $log.info "Sending messages from #{r1} to #{r2}"
    else
      $log.warn "Would send #{r1}..#{r2}, but there's no target or dry-run"
    end
  else
    $log.info "Could not download posts"
  end
end


