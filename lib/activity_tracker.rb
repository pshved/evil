# For documentation, see http://coldattic.info/shvedsky/pro/blogs/a-foo-walks-into-a-bar/posts/77
class ActivityTracker
  def initialize(opts = {})
    @tick = opts[:tick]
    @period = opts[:period]
    @width = opts[:width] || ACTIVITY_CACHE_WIDTH
    @scope = opts[:scope] || 'activity_tracker'
    @commit_period = opts[:commit_period]
    @read_proc = opts[:read_proc] || proc {}
    @update_proc = opts[:update_proc] || proc {}
    @commit_proc = opts[:commit_proc] || proc {}
  end

  # Activity queries
  # In these queries, we do not rely that the table is cleaned up, and explicitely query the latest records.

  def read
    @read_proc[]
  end

  # Activity mutators

  # Write a single activity event
  def event(*args)
    # get the bucket
    now = Time.now
    t = bucket(now)
    bucket = Random.rand(@width)
    cache_name = "#{@scope}_#{t}_#{bucket}"


    # Load from name and paste there
    # FIXME: dup due to Rails <=3.1 bug with frozen records returned by Rails cache.
    info = (Rails.cache.read(cache_name) || []).dup
    info = @update_proc[info,*args]
    Rails.cache.write(cache_name, info, :expires_in => @period)
  end

  # This function flushes everything that happened during the last @period seconds.  It tries to work without many race conditions even if several threads run this concurrently, optimizing for the case when they start nearly simultaneously.
  def commit
    # determine the list of cache entities we're to collect.  We do not collect the cache the +click+ function would otherwise write to here.
    # NOTE that we collect the data twice as old as the expected commit period, because older data should have been committed by previous calls via the scheduler.
    now = Time.now
    t = bucket(now)
    n_timestamps = (2*@commit_period / @tick) + 1 + 1
    caches = (1..n_timestamps-1).map{|shift| t - shift*@tick}.map{|t| "#{@scope}_#{t}"}.map{|ts| (0..@width-1).map{|bucket| "#{ts}_#{bucket}"}}.flatten(1)

    # Now read all these caches, collect the data, and insert it into the persistent storage

    # Get the records, and clear the cache (if it had something).  Do not forget to throw NILs away.
    # We shuffle to decrease the chance that we'll have a race condition here.
    records = caches.shuffle.map do |cache|
      r = Rails.cache.read(cache)
      Rails.cache.delete(cache) if r
      r
    end.compact.flatten(1)

    # Commit the records collected
    @commit_proc[records]
  end

  private
  def bucket(_t = Time.now)
    t = _t.to_i
    t - t.modulo(@tick)
  end
end
