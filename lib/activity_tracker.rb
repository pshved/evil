class ActivityTracker
  def initialize(tick, period, width = ACTIVITY_CACHE_WIDTH, scope = 'activity_tracker')
    @tick = tick
    @period = period
    @width = width
    @scope = scope
  end

  # Activity queries
  public
  def hosts_activity
    Rails.cache.fetch('activity_hosts', :expires_in => @period) {Activity.select('distinct host').count}
  end
  def clicks_activity
    Rails.cache.fetch('activity_clicks', :expires_in => @period) {Activity.select('host').count}
  end

  # Activity writes

  # Write a single activity event
  def click!(host)
    # get the bucket
    now = Time.now
    t = bucket(now)
    bucket = Random.rand(@width)
    cache_name = "#{@scope}_#{t}_#{bucket}"


    # Load from name and paste there
    # FIXME: dup due to Rails <=3.1 bug
    info = (Rails.cache.read(cache_name) || []).dup
    # NOTE: keep this synchronized with +recycle+!
    info << [now, host]
    Rails.cache.write(cache_name, info, :expires_in => @period)

    puts "Ac write to #{cache_name} #{info.length} for #{@period}"
  end

  # This function flushes everything that happened during the last @period seconds.  It's important that you don't let several threads run this in parallel.
  def commit
    # determine the list of cache entities we're to collect.  We do not collect the cache the +click+ function would otherwise write to here.
    now = Time.now
    t = bucket(now)
    n_timestamps = (@period / @tick) + 1 + 1
    caches = (1..n_timestamps-1).map{|shift| t - shift*@tick}.map{|t| "#{@scope}_#{t}"}.map{|ts| (0..@width-1).map{|bucket| "#{ts}_#{bucket}"}}.flatten(1)

    # Now read all these caches, collect the data, and insert it into the persistent storage
 
    # Get the records.  Do not forget to throw NILs away.
    records = caches.map{|cache| Rails.cache.read(cache)}.compact.flatten(1)
    puts "Recs #{records.inspect}"
    # Clear the cache
    caches.map{|cache| Rails.cache.delete(cache)}

    puts "Queried #{caches.length} caches yielding #{records.length} records"

    # Convert these records to ActiveRecord initialization hashes
    # NOTE: keep this synchronized with +click!+
    inits = records.map{|rec| {:created_at => rec[0], :host => rec[1]}}
    Activity.create(inits) unless inits.empty?
    # Also, delete old activities that aren't interesting to anyone
    Activity.delete_all(['created_at < ?', Time.now - @period])
  end

  private
  def last_buck
  end

  def bucket(_t = Time.now)
    t = _t.to_i
    t - t.modulo(@tick)
  end
end
