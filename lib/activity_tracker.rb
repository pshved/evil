class ActivityTracker
  def initialize(tick, period, read_expiry, width = ACTIVITY_CACHE_WIDTH, scope = 'activity_tracker')
    @tick = tick
    @period = period
    @width = width
    @scope = scope
    @read_expiry = read_expiry
  end

  # Activity queries
  public
  def hosts_activity
    Rails.cache.fetch('activity_hosts', :expires_in => @read_expiry) {Activity.select('distinct host').count}
  end
  def clicks_activity
    Rails.cache.fetch('activity_clicks', :expires_in => @read_expiry) {Activity.select('host').count}
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
    # We shuffle to decrease the change that we'll have a race condition here.
    records = caches.shuffle.map do |cache|
      r = Rails.cache.read(cache)
      Rails.cache.delete(cache)
      r
    end.compact.flatten(1)
    # Clear the cache

    # Convert these records to ActiveRecord initialization hashes
    # Unfortunately, if we use something like "Activity.create(inits)", we'll create a lot of transactions anyway.  We have to resort to raw SQL :-(
    # (or, install ActiveRecord-extensions gem, but it would be used here only
    unless records.empty?
      inserts = records.inject([]) {|acc, rec| acc + ["('#{rec[1]}','#{rec[0].to_formatted_s(:db)}')"]}
      # NOTE: keep this synchronized with +click!+
      Activity.connection.execute "INSERT into activities(host,created_at) VALUES #{inserts.join(", ")}"
    end
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
