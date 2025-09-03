#!/bin/bash

# This script uses lftp to download the wp-content directory from 
# www.website.com and then tars the downloaded directory with today's date. 
# It then cleans up after itself by deleting the downloaded directory and
# removing any .tar.gz files that are older than 14 days.

lftp sftp:?:?@www.website.com:22 -e 'mirror --verbose --use-pget-n=8 -c /wp-content /var/www.website.com/wp-content; exit'

tar czfp /var/www.website.com/wp-content.20$(date +%y%m%d).tar.gz /var/www.website.com/wp-content/

rm -rf /var/www.website.com/wp-content/

find /var/www.website.com/ -mtime +14 -exec rm -rf '{}' \;

# End.
