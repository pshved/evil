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

options = {:strategy => 'xmlfp', :from => 1}
OptionParser.new do |opts|
  opts.banner = "Usage: ./download.rb [options]"

  opts.on("-s STRATEGY", "--strategy", "What download strategy to use.  Available: xmlfp") do |v|
    options[:strategy] = v
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
  attr_reader :current
  def initialize(initial)
    @current = initial
  end
  def move(_)
    nil
  end
  def print
    "<NONE>"
  end
end

class UpStrategy < NullStrategy
  def move(was_success)
    @current += 1 if was_success
    # Do not change strategy for now
    self
  end
  def print
    "<UP from #{@current}>"
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

class AlterStrategy < NullStrategy
  def initialize(*strategies)
    @strategies = strategies
    raise "Specify at least one strategy, please!" if @strategies.length < 0
    @i = 0
  end

  def move(success)
    i = @i
    #@strategies[i] = @strategies[i].move(success)
    @strategies[i] = @strategies[i].move(success)
    unless @strategies[i]
      @strategies.delete_at(i)
    end
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
end

class Downloader
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
    r = download
    @strategy = @strategy.move(r)
    $log.debug "Work: next @current=#{current}, state=#{@strategy.print}"
    r
  end

  attr_accessor :last_downloaded

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

    # Write then move, because we don't want incomplete files in our cache!
    if result
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

class XmlfpDownloader < Downloader
  def initialize(opts = {})
    super(opts)
  end

  def download
    @last_downloaded = current
    begin
      body = cache "#{current}.html" do
        $log.debug "Downloading #{make_url}"
        rsp = Net::HTTP.get_response(URI(make_url))
        rsp.body
      end
      $log.debug "Response: #{body ? body[0..10] : body.inspect}..."
      if body =~ /Ошибочный запрос на действие/
        $log.debug "Response matches bad regexp, retry"
        return false
      end
      doc = Hpricot(body)
      # Hpricot is "liberal" enough to return empty strings if the element was not found
      status = doc.search(%Q(//message[@id="#{current}"]/status)).inner_html
      $log.debug %Q(Status found by //message[@id="#{current}"]/status is '#{status}')

      return false if status == 'not_exists'

      # OK
      return body
    rescue Net::HTTPBadResponse
      false
    end
  end

  def make_url
    %Q(#{@base_path}/?xmlfpread=#{current})
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

dler = DownloaderFactory.make('xmlfp',options)

puts dler.test.inspect

while true
  $log.debug "iteration"
  r = dler.work
  $log.debug "Result: #{r.inspect}"
  if r
    $log.info "Downloaded post #{dler.last_downloaded} entitled #{Hpricot(r).search(%Q(//message[@id="#{dler.last_downloaded}"]/content/title)).inner_text}"
  else
    $log.info "Could not download post #{dler.last_downloaded}"
  end
  sleep(2) unless dler.last_was_cached?
end


