# Is buffered logging faster to write out?

This experiment seeks to answer questions about the speed of python logging.  Specifically:

1. Is python logging to a file faster than printing to stdout?
2. Does it make a difference if the logging is being written to SCRATCH vs L_SCRATCH?
3. Python offers a buffered logging handler; does that make a difference?

Results are timed 100 times and written to a CSV.

And no, there's a negligible difference between the various methods.  Print
statements were like a hundredth of a second faster on average (in aggregate
over tens of thousands of print statements).

So, just log your messages to a file and don't worry about where they're going; it all appears to be fine.
