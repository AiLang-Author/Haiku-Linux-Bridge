#!/bin/sh
# Short name for sendkey. Loop so a crash mid-test gets dismissed.
# License: Public Domain / CC0 1.0 Universal
n=${1:-30}
i=0
while [ "$i" -lt "$n" ]; do
	sh /boot/home/dismiss_crash.sh
	i=$((i + 1))
	sleep 1
done
