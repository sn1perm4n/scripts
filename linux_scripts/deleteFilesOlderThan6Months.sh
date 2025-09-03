#!/bin/bash

# This script deletes files older than 182 days from /*/*/*/*.
# This script resides in /usr/local/bin and is run daily at x AM via cronjob.

find /*/*/*/* -mtime +182 -exec rm -rf '{}' \;

# End.
