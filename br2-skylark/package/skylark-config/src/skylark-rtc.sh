#!/bin/sh
# Skylark RTC helper (DS1307).
#   restore : system clock <- RTC (boot, before time-set.target)
#   sync    : RTC <- system clock, if NTP-synchronized and drift > MAX_DRIFT
#   save    : RTC <- system clock, if NTP-synchronized (shutdown)
#   status  : print RTC, system time and drift
RTC_NAME=rtc-ds1307
MAX_DRIFT=2
[ -r /etc/skylark/rtc.conf ] && . /etc/skylark/rtc.conf
SYNCED=/run/systemd/timesync/synchronized

find_rtc() {
	for r in /sys/class/rtc/rtc*; do
		[ -r "$r/name" ] && grep -q "$RTC_NAME" "$r/name" && { echo "${r##*/}"; return 0; }
	done
	return 1
}

rtc_epoch() { cat "/sys/class/rtc/$RTC/since_epoch" 2>/dev/null; }

# run a command up to 3 times (I2C2 to the DS1307 occasionally times out)
retry() {
	for i in 1 2 3; do
		"$@" && return 0
		sleep 1
	done
	return 1
}

RTC=$(find_rtc) || { echo "skylark-rtc: no $RTC_NAME device"; exit 0; }

case "$1" in
restore)
	t=$(rtc_epoch) || { sleep 1; t=$(rtc_epoch); }
	# 2025-01-01: anything older means the RTC lost its time
	if [ -z "$t" ] || [ "$t" -lt 1735689600 ]; then
		echo "skylark-rtc: $RTC has no valid time, leaving system clock alone"
		exit 0
	fi
	now=$(date +%s)
	if [ "$t" -le "$now" ]; then
		# never move the clock backwards (timesyncd may already have a newer stamp)
		echo "skylark-rtc: $RTC ($t) not newer than system clock ($now), keeping system clock"
		exit 0
	fi
	retry hwclock -f "/dev/$RTC" -u -s && echo "skylark-rtc: system clock set from $RTC: $(date -u '+%F %T') UTC"
	;;
sync|save)
	[ -e "$SYNCED" ] || { echo "skylark-rtc: system clock not NTP-synchronized, not touching $RTC"; exit 0; }
	now=$(date +%s)
	t=$(rtc_epoch)
	if [ -n "$t" ]; then
		d=$((now - t)); [ $d -lt 0 ] && d=$((-d))
	else
		t=invalid; d=999999999
	fi
	if [ "$1" = save ] || [ "$d" -gt "$MAX_DRIFT" ]; then
		retry hwclock -f "/dev/$RTC" -u -w &&
			echo "skylark-rtc: $RTC updated from NTP time (was $t, off by ${d}s)"
	fi
	;;
status)
	t=$(rtc_epoch); now=$(date +%s)
	echo "rtc:    /dev/$RTC ${t:-invalid} $( [ -n "$t" ] && date -u -d "@$t" '+%F %T' )"
	echo "system: $now $(date -u '+%F %T') UTC"
	[ -n "$t" ] && echo "drift:  $((now - t)) s"
	[ -e "$SYNCED" ] && echo "ntp:    synchronized" || echo "ntp:    not synchronized"
	;;
*)
	echo "usage: $0 restore|sync|save|status"; exit 1 ;;
esac
