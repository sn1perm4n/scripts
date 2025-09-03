#!/bin/sh

# RAID Data Scrubbing

/bin/echo check > /sys/block/md0/md/sync_action
/bin/echo check > /sys/block/md1/md/sync_action
/bin/echo check > /sys/block/md2/md/sync_action

# End.
