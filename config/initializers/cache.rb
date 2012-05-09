# For how much time threads are cached (doesn't help much though)
THREAD_CACHE_TIME = 1.day

# For how long configuration entries are cached (used for site-wide configuration, and the default view)
CONFG_CACHE_TIME = 30.seconds

# How the index page is cached
#
# These times show how fast the index will respond to the actions that modify how an index page looks.
# The first shows for how long the thread is cached, the second should be greater than the time to update the page 
INDEX_CACHE_TIME = 6.seconds
INDEX_CACHE_UPDATE_TIME = 4.seconds
# For how long the whole index and posts HTMLs are cached for unregistered users
UNREG_VIEW_CACHE_TIME = 3.seconds
UNREG_VIEW_CACHE_UPDATE_TIME = 3.seconds

# Activity cache on the index page. 
# NOTE: if you change this, make sure to do the same in config/schedule.rb!
ACTIVITY_CACHE_TIME = 30.seconds
# The more this value is, the more precise activity calculation will be (will drop less accesses).  Approximately, this should be at least twice greater than the number of _simlultaneous_ activity writes you need
ACTIVITY_CACHE_WIDTH = 15
# The more this value is, the more time is spent on writes.  However, if this will be very small, if will put a lot of trash in the cache.  5 seconds should be optimal.
ACTIVITY_CACHE_TICK = 5.seconds

# POST CLICKS
# If we update each thread at each click, we'll lose the ability to cache them.
# Instead, we drop precision in sake of performance.
# When a post has less than CLICK_UPDATE_THRESHOLD clicks, the thread is always updated.  Otherwise, the thread is updates once per CLICK_DELAY_RATE clicks (as decided by random number generator)
CLICK_UPDATE_THRESHOLD = 10
CLICK_DELAY_RATE = 5
# How often post click information is committed
POST_CLICK_CACHE_TIME = 5.seconds
# The more this value is, the more precise activity calculation will be (will drop less accesses).  Approximately, this should be at least twice greater than the number of _simlultaneous_ activity writes you need
POST_CLICK_CACHE_WIDTH = 66


# SOURCE UPDATE CLICKS
# When an external source is requested, it transfers into "hot" mode, so that the external source is requested more frequently.  This frequency is stored in the database, and it also goes through a wide cache
SOURCE_UPDATE_CACHE_WIDTH = 30
SOURCE_UPDATE_CACHE_TIME = 5.seconds
# How long after the last request the source should remain in the hot mode
SOURCE_UPDATE_HOT_TIMEOUT = 5.minutes
