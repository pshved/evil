# If we update each thread at each click, we'll lose the ability to cache them.
# Instead, we drop precision in sake of performance.
# When a post has less than CLICK_UPDATE_THRESHOLD clicks, the thread is always updated.  Otherwise, the thread is updates once per CLICK_DELAY_RATE clicks (as decided by random number generator)
CLICK_UPDATE_THRESHOLD = 3
CLICK_DELAY_RATE = 5
