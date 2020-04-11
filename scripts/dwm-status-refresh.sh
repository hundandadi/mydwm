#!/bin/bash
# Screenshot: http://s.natalian.org/2013-08-17/dwm_status.png
# Network speed stuff stolen from http://linuxclues.blogspot.sg/2009/11/shell-script-show-network-speed.html

# This function parses /proc/net/dev file searching for a line containing $interface data.
# Within that line, the first and ninth numbers after ':' are respectively the received and transmited bytes.
# function get_bytes {
# 	# Find active network interface
# 	interface=$(ip route get 8.8.8.8 2>/dev/null| awk '{print $5}')
# 	line=$(grep $interface /proc/net/dev | cut -d ':' -f 2 | awk '{print "received_bytes="$1, "transmitted_bytes="$9}')
# 	eval $line
# 	now=$(date +%s%N)
# }

# Function which calculates the speed using actual and old byte number.
# Speed is shown in KByte per second when greater or equal than 1 KByte per second.
# This function should be called each second.

function batterybar {
    readarray -t output <<< $(acpi battery)
    battery_count=${#output[@]}

    for line in "${output[@]}";
    do
        percentages+=($(echo "$line" | grep -o -m1 '[0-9]\{1,3\}%' | tr -d '%'))
        statuses+=($(echo "$line" | egrep -o -m1 'Discharging|Charging|AC|Full|Unknown'))
        remaining=$(echo "$line" | egrep -o -m1 '[0-9][0-9]:[0-9][0-9]')
        if [[ -n $remaining ]]; then
            remainings+=(" ($remaining)")
        else 
            remainings+=("")
        fi
    done

    squares="■"

    #There are 8 colors that reflect the current battery percentage when 
    #discharging
    dis_colors=("${C1:-#FF0027}" "${C2:-#FF3B05}" "${C3:-#FFB923}" 
                "${C4:-#FFD000}" "${C5:-#E4FF00}" "${C6:-#ADFF00}"
                "${C7:-#6DFF00}" "${C8:-#10BA00}") 
    charging_color="${CHARGING_COLOR:-#00AFE3}"
    full_color="${FULL_COLOR:-#FFFFFF}"
    ac_color="${AC_COLOR:-#535353}"


    while getopts 1:2:3:4:5:6:7:8:c:f:a:h opt; do
        case "$opt" in
            1) dis_colors[0]="$OPTARG";;
            2) dis_colors[1]="$OPTARG";;
            3) dis_colors[2]="$OPTARG";;
            4) dis_colors[3]="$OPTARG";;
            5) dis_colors[4]="$OPTARG";;
            6) dis_colors[5]="$OPTARG";;
            7) dis_colors[6]="$OPTARG";;
            8) dis_colors[7]="$OPTARG";;
            c) charging_color="$OPTARG";;
            f) full_color="$OPTARG";;
            a) ac_color="$OPTARG";;
            h) printf "Usage: batterybar [OPTION] color
            When discharging, there are 8 [1-8] levels colors.
            You can specify custom colors, for example:
            
            batterybar -1 red -2 \"#F6F6F6\" -8 green
            
            You can also specify the colors for the charging, AC and
            charged states:
            
            batterybar -c green -f white -a \"#EEEEEE\"\n";
            exit 0;
        esac
    done

    end=$(($battery_count - 1))
    for i in $(seq 0 $end);
    do
        if (( percentages[$i] > 0 && percentages[$i] < 15  )); then
            squares=""
        elif (( percentages[$i] >= 15 && percentages[$i] < 30 )); then
            squares=""
        elif (( percentages[$i] >= 30 && percentages[$i] < 55 )); then
            squares=""
        elif (( percentages[$i] >= 55 && percentages[$i] < 90 )); then
            squares=""
        elif (( percentages[$i] >=90 )); then
            squares=""
        fi

        if [[ "${statuses[$i]}" = "Unknown" ]]; then
            squares="?$squares"
        fi

        case "${statuses[$i]}" in
        "Charging")
            color="$charging_color"
        ;;
        "Full")
            color="$full_color"
        ;;
        "AC")
            color="$ac_color"
        ;;
        "Discharging"|"Unknown")
            if (( percentages[$i] >= 0 && percentages[$i] < 10 )); then
                color="${dis_colors[0]}"
            elif (( percentages[$i] >= 10 && percentages[$i] < 20 )); then
                color="${dis_colors[1]}"
            elif (( percentages[$i] >= 20 && percentages[$i] < 30 )); then
                color="${dis_colors[2]}"
            elif (( percentages[$i] >= 30 && percentages[$i] < 40 )); then
                color="${dis_colors[3]}"
            elif (( percentages[$i] >= 40 && percentages[$i] < 60 )); then
                color="${dis_colors[4]}"
            elif (( percentages[$i] >= 60 && percentages[$i] < 70 )); then
                color="${dis_colors[5]}"
            elif (( percentages[$i] >= 70 && percentages[$i] < 80 )); then
                color="${dis_colors[6]}"
            elif (( percentages[$i] >= 80 )); then
                color="${dis_colors[7]}"
            fi
        ;;
        esac
        message="^c$color^$squares ${percentages[$i]}%" 
    done

    echo $message
}

function bandwidth {
	[[ -z "$INLABEL" ]] && INLABEL=""
	[[ -z "$OUTLABEL" ]] && OUTLABEL=""

	# Use the provided interface, otherwise the device used for the default route.
	if [[ -z $INTERFACE ]] && [[ -n $BLOCK_INSTANCE ]]; then
	INTERFACE=$BLOCK_INSTANCE
	elif [[ -z $INTERFACE ]]; then
	INTERFACE=$(ip route | awk '/^default/ { print $5 ; exit }')
	fi

	# Exit if there is no default route
	[[ -z "$INTERFACE" ]] && exit

	# Issue #36 compliant.
	if ! [ -e "/sys/class/net/${INTERFACE}/operstate" ] || \
		(! [ "$TREAT_UNKNOWN_AS_UP" = "1" ] && 
		! [ "`cat /sys/class/net/${INTERFACE}/operstate`" = "up" ])
	then
		echo "$INTERFACE down"
		echo "$INTERFACE down"
		echo "#FF0000"
		exit 0
	fi

	# path to store the old results in
	path="/dev/shm/$(basename $0)-${INTERFACE}"

	# grabbing data for each adapter.
	read rx < "/sys/class/net/${INTERFACE}/statistics/rx_bytes"
	read tx < "/sys/class/net/${INTERFACE}/statistics/tx_bytes"

	# get time
	time=$(date +%s)

	# write current data if file does not exist. Do not exit, this will cause
	# problems if this file is sourced instead of executed as another process.
	if ! [[ -f "${path}" ]]; then
	echo "${time} ${rx} ${tx}" > "${path}"
	chmod 0666 "${path}"
	fi


	# read previous state and update data storage
	read old < "${path}"
	echo "${time} ${rx} ${tx}" > "${path}"

	# parse old data and calc time passed
	old=(${old//;/ })
	time_diff=$(( $time - ${old[0]} ))

	# sanity check: has a positive amount of time passed
	[[ "${time_diff}" -gt 0 ]] || exit

	# calc bytes transferred, and their rate in byte/s
	rx_diff=$(( $rx - ${old[1]} ))
	tx_diff=$(( $tx - ${old[2]} ))
	rx_rate=$(( $rx_diff / $time_diff ))
	tx_rate=$(( $tx_diff / $time_diff ))

	# shift by 10 bytes to get KiB/s. If the value is larger than
	# 1024^2 = 1048576, then display MiB/s instead

	# incoming
	echo -n "$INLABEL"
	rx_kib=$(( $rx_rate >> 10 ))
	if hash bc 2>/dev/null && [[ "$rx_rate" -gt 1048576 ]]; then
	printf '%sM' "`echo "scale=1; $rx_kib / 1024" | bc`"
	else
	echo -n "${rx_kib}K"
	fi

	echo -n " "

	# outgoing
	echo -n "$OUTLABEL"
	tx_kib=$(( $tx_rate >> 10 ))
	if hash bc 2>/dev/null && [[ "$tx_rate" -gt 1048576 ]]; then
	printf '%sM\n' "`echo "scale=1; $tx_kib / 1024" | bc`"
	else
	echo "${tx_kib}K"
	fi
}

dwm_temperature(){
	TEMP=$(sensors | grep Package | awk '{print substr($4, 2, length($0)-3)}')
	if [ "$TEMP" -gt 0 ] && [ "$TEMP" -le 25 ]; then
		printf "^c#FFFFFF^ %s%%" "$TEMP"
	elif [ "$TEMP" -gt 26 ] && [ "$TEMP" -le 50 ]; then
		printf "^c#FFFFFF^ %s%%" "$TEMP"
	elif [ "$TEMP" -gt 51 ] && [ "$TEMP" -le 75 ]; then
		printf "^c#FFFFFF^ %s%%" "$TEMP"
	else
		printf "^c#FF0000^ %s%%" "$TEMP"
	fi
}
# function get_velocity {
# 	value=$1
# 	old_value=$2
# 	now=$3

# 	timediff=$(($now - $old_time))
# 	velKB=$(echo "1000000000*($value-$old_value)/1024/$timediff" | bc)
# 	if test "$velKB" -gt 1024
# 	then
# 		echo $(echo "scale=2; $velKB/1024" | bc)MB/s
# 	else
# 		echo ${velKB}KB/s
# 	fi
# }

# # Get initial values
# get_bytes
# old_received_bytes=$received_bytes
# old_transmitted_bytes=$transmitted_bytes
# old_time=$now

# print_volume() {
# 	volume="$(amixer get Master | tail -n1 | sed -r 's/.*\[(.*)%\].*/\1/')"
# 	if test "$volume" -gt 0
# 	then
# 		echo -e "\uE05D${volume}"
# 	else
# 		echo -e "Mute"
# 	fi
# }

# print_mem(){
# 	memfree=$(($(grep -m1 'MemAvailable:' /proc/meminfo | awk '{print $2}') / 1024))
# 	echo -e "$memfree"
# }

# print_temp(){
# 	test -f /sys/class/thermal/thermal_zone0/temp || return 0
# 	echo $(head -c 2 /sys/class/thermal/thermal_zone0/temp)C
# }

#!/bin/bash

# get_time_until_charged() {

# 	# parses acpitool's battery info for the remaining charge of all batteries and sums them up
# 	sum_remaining_charge=$(acpitool -B | grep -E 'Remaining capacity' | awk '{print $4}' | grep -Eo "[0-9]+" | paste -sd+ | bc);

# 	# finds the rate at which the batteries being drained at
# 	present_rate=$(acpitool -B | grep -E 'Present rate' | awk '{print $4}' | grep -Eo "[0-9]+" | paste -sd+ | bc);

# 	# divides current charge by the rate at which it's falling, then converts it into seconds for `date`
# 	seconds=$(bc <<< "scale = 10; ($sum_remaining_charge / $present_rate) * 3600");

# 	# prettifies the seconds into h:mm:ss format
# 	pretty_time=$(date -u -d @${seconds} +%T);

# 	echo $pretty_time;
# }

# get_battery_combined_percent() {

# 	# get charge of all batteries, combine them
# 	total_charge=$(expr $(acpi -b | awk '{print $4}' | grep -Eo "[0-9]+" | paste -sd+ | bc));

# 	# get amount of batteries in the device
# 	battery_number=$(acpi -b | wc -l);

# 	percent=$(expr $total_charge / $battery_number);

# 	echo $percent;
# }

# get_battery_charging_status() {

# 	if $(acpi -b | grep --quiet Discharging)
# 	then
# 		echo "🔋";
# 	else # acpi can give Unknown or Charging if charging, https://unix.stackexchange.com/questions/203741/lenovo-t440s-battery-status-unknown-but-charging
# 		echo "🔌";
# 	fi
# }



# print_bat(){
# 	#hash acpi || return 0
# 	#onl="$(grep "on-line" <(acpi -V))"
# 	#charge="$(awk '{ sum += $1 } END { print sum }' /sys/class/power_supply/BAT*/capacity)%"
# 	#if test -z "$onl"
# 	#then
# 		## suspend when we close the lid
# 		##systemctl --user stop inhibit-lid-sleep-on-battery.service
# 		#echo -e "${charge}"
# 	#else
# 		## On mains! no need to suspend
# 		##systemctl --user start inhibit-lid-sleep-on-battery.service
# 		#echo -e "${charge}"
# 	#fi
# 	#echo "$(get_battery_charging_status) $(get_battery_combined_percent)%, $(get_time_until_charged )";
# 	echo "$(get_battery_charging_status) $(get_battery_combined_percent)%, $(get_time_until_charged )";
# }

print_date(){
	date '+%m月%d日 %H:%M'
}

# show_record(){
# 	test -f /tmp/r2d2 || return
# 	rp=$(cat /tmp/r2d2 | awk '{print $2}')
# 	size=$(du -h $rp | awk '{print $1}')
# 	echo "$size $(basename $rp)"
# }
dwm_alsa () {
    VOL=$(amixer get Master | tail -n1 | sed -r "s/.*\[(.*)%\].*/\1/")
    printf "%s" "$SEP1"
    if [ "$IDENTIFIER" = "unicode" ]; then
        if [ "$VOL" -eq 0 ]; then
            printf "^c#a0a0a0^"
        elif [ "$VOL" -gt 0 ] && [ "$VOL" -le 25 ]; then
            printf " %s%%" "$VOL"
        elif [ "$VOL" -gt 26 ] && [ "$VOL" -le 50 ]; then
            printf " %s%%" "$VOL"
        elif [ "$VOL" -gt 51 ] && [ "$VOL" -le 75 ]; then
            printf " %s%%" "$VOL"
        else
            printf " %s%%" "$VOL"
        fi
    else
        if [ "$VOL" -eq 0 ]; then
            printf "MUTE"
        elif [ "$VOL" -gt 0 ] && [ "$VOL" -le 33 ]; then
            printf "VOL %s%%" "$VOL"
        elif [ "$VOL" -gt 33 ] && [ "$VOL" -le 66 ]; then
            printf "VOL %s%%" "$VOL"
        else
            printf "VOL %s%%" "$VOL"
        fi
    fi
    printf "%s\n" "$SEP2"
}

# LOC=$(readlink -f "$0")
# DIR=$(dirname "$LOC")
# export IDENTIFIER="unicode"

#. "$DIR/dwmbar-functions/dwm_transmission.sh"
#. "$DIR/dwmbar-functions/dwm_cmus.sh"
#. "$DIR/dwmbar-functions/dwm_resources.sh"
#. "$DIR/dwmbar-functions/dwm_battery.sh"
#. "$DIR/dwmbar-functions/dwm_mail.sh"
#. "$DIR/dwmbar-functions/dwm_backlight.sh"
# . "$DIR/dwmbar-functions/dwm_alsa.sh"
#. "$DIR/dwmbar-functions/dwm_pulse.sh"
#. "$DIR/dwmbar-functions/dwm_weather.sh"
#. "$DIR/dwmbar-functions/dwm_vpn.sh"
#. "$DIR/dwmbar-functions/dwm_network.sh"
#. "$DIR/dwmbar-functions/dwm_keyboard.sh"
#. "$DIR/dwmbar-functions/dwm_ccurse.sh"
#. "$DIR/dwmbar-functions/dwm_date.sh"

# get_bytes

# Calculates speeds
# vel_recv=$(get_velocity $received_bytes $old_received_bytes $now)
# vel_trans=$(get_velocity $transmitted_bytes $old_transmitted_bytes $now)

xsetroot -name "$(dwm_temperature) $(batterybar) ^c#FFFFFF^$(dwm_alsa) ^c#FFFFFF^$(print_date)"

# Update old values to perform new calculations
# old_received_bytes=$received_bytes
# old_transmitted_bytes=$transmitted_bytes
# old_time=$now

exit 0
