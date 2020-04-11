#!/bin/bash
status=""
if [$batperc -le 10]; then
	# use "warning" color
	status+="\x03 BAT: $batperc"
elif [$batperc -le 5]; then
	# use "error" color
	status+="\x04 BAT: $batperc"
else
	# default is normal color
	status+="BAT: $batperc"
fi
# switch back to normal color for date
status+="\x01| "+$(date)
echo -e $status