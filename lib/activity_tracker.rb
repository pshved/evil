class ActivityTracker
  def initialize(tick, period, read_expiry, width = ACTIVITY_CACHE_WIDTH, scope = 'activity_tracker')
    @tick = tick
    @period = period
    @width = width
    @scope = scope
    @read_expiry = read_expiry
  end

  # Activity queries

  def hosts_activity
    Rails.cache.fetch('activity_hosts', :expires_in => @read_expiry) {Activity.select('distinct host').count}
  end
  def clicks_activity
    Rails.cache.fetch('activity_clicks', :expires_in => @read_expiry) {Activity.select('host').count}
  end

  # Activity mutators

  # Write a single activity event
  def click!(host)
    # get the bucket
    now = Time.now
    t = bucket(now)
    bucket = Random.rand(@width)
    cache_name = "#{@scope}_#{t}_#{bucket}"


    # Load from name and paste there
    # FIXME: dup due to Rails <=3.1 bug with frozen records returned by Rails cache.
    info = (Rails.cache.read(cache_name) || []).dup
    # NOTE: keep this synchronized with +commit+ (see at the bottom)!
    info << [now, host]
    Rails.cache.write(cache_name, info, :expires_in => @period)
  end

  # This function flushes everything that happened during the last @period seconds.  It tries to work without many race conditions even if several threads run this concurrently, optimizing for the case when they start nearly simultaneously.
  def commit
    # determine the list of cache entities we're to collect.  We do not collect the cache the +click+ function would otherwise write to here.
    now = Time.now
    t = bucket(now)
    n_timestamps = (@period / @tick) + 1 + 1
    caches = (1..n_timestamps-1).map{|shift| t - shift*@tick}.map{|t| "#{@scope}_#{t}"}.map{|ts| (0..@width-1).map{|bucket| "#{ts}_#{bucket}"}}.flatten(1)

    # Now read all these caches, collect the data, and insert it into the persistent storage

    # Get the records, and clear the cache (if it had something).  Do not forget to throw NILs away.
    # We shuffle to decrease the chance that we'll have a race condition here.
    records = caches.shuffle.map do |cache|
      r = Rails.cache.read(cache)
      Rails.cache.delete(cache) if r
      r
    end.compact.flatten(1)

    # Convert these records to ActiveRecord initialization hashes
    # Unfortunately, even if we use something like "Activity.create(inits)", we'll create a lot of transactions/DB inserts anyway.  We have to resort to raw SQL to use a single, multi-row insert :-(
    # (or, install ActiveRecord-extensions gem, but it would be used here only)
    unless records.empty?
      inserts = records.inject([]) {|acc, rec| acc + ["('#{rec[1]}','#{rec[0].to_formatted_s(:db)}')"]}
      # NOTE: keep this synchronized with +click!+
      Activity.connection.execute "INSERT into activities(host,created_at) VALUES #{inserts.join(", ")}"
    end
    # Also, delete old activities that aren't interesting anymore
    Activity.delete_all(['created_at < ?', Time.now - @period])
  end

  private
  def bucket(_t = Time.now)
    t = _t.to_i
    t - t.modulo(@tick)
  end
end
