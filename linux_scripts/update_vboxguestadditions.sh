#!/bin/bash

# Update VirtualBox Guest Additions

mount -r /dev/cdrom /media/VirtualBoxGuestAdditions/
cd /media/VirtualBoxGuestAdditions/
./VBoxLinuxAdditions.run

# End.












