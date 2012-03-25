# For how much time threads are cached (doesn't help much though)
THREAD_CACHE_TIME = 1.day

# For how long configuration entries are cached (used for site-wide configuration, and the default view)
CONFG_CACHE_TIME = 30.seconds

# How the index page is cached
#
# These times show how fast the index will respond to the actions that modify how an index page looks.
# The first shows for how long the thread is cached, the second should be greater than the time to update the page 
INDEX_CACHE_TIME = 10.seconds
INDEX_CACHE_UPDATE_TIME = 1.seconds

# Activity cache on the index page
ACTIVITY_CACHE_TIME = 5.seconds

