# shellcheck shell=bash
# Show if stats by sampling /sys/.
# Originally stolen from http://unix.stackexchange.com/questions/41346/upload-download-speed-in-tmux-status-line

run_segment() {
	sleeptime="${TMUX_POWERLINE_SEG_IFSTAT_SYS_SLEEP_TIME:-0.5}"
	if [ -z "$TMUX_POWERLINE_SEG_IFSTAT_SYS_INTERFACE" ]; then
		iface=$(ip route show default | grep -o "dev.*" | cut -d ' ' -f 2 | head -1)
		if [ -z "$iface" ]; then
			iface=$(awk '{if($2>0 && NR > 2) print substr($1, 0, index($1, ":") - 1)}' /proc/net/dev | sed '/^lo$/d' | head -1)
		fi
	else
		iface="$TMUX_POWERLINE_SEG_IFSTAT_SYS_INTERFACE"
	fi
	type="☫ ${iface:0:4}"
	RXB=$(</sys/class/net/"$iface"/statistics/rx_bytes)
	# TXB=$(</sys/class/net/"$iface"/statistics/tx_bytes)
	sleep "$sleeptime"
	RXBN=$(</sys/class/net/"$iface"/statistics/rx_bytes)
	# TXBN=$(</sys/class/net/"$iface"/statistics/tx_bytes)
	RXDIF=$(echo "$((RXBN - RXB)) / 1024 / ${sleeptime}" | bc)
	# TXDIF=$(echo "$((TXBN - TXB)) / 1024 / ${sleeptime}" | bc)

	if [ "$RXDIF" -gt 1024 ]; then
		RXDIF=$(echo "scale=1;${RXDIF} / 1024" | bc)
		RXDIF_UNIT="M/s"
	else
		RXDIF_UNIT="K/s"
	fi
	# if [ "$TXDIF" -gt 1024 ]; then
	# 	TXDIF=$(echo "scale=1;${TXDIF} / 1024" | bc)
	# 	TXDIF_UNIT="M/s"
	# else
	# 	TXDIF_UNIT="K/s"
	# fi

	# NOTE: '%5.01' for fixed length always
	# printf "${type} ⇊ %5.01f${RXDIF_UNIT} ⇈ %5.01f${TXDIF_UNIT}" "${RXDIF}" "${TXDIF}"
	printf "${type} ⇊ %5.01f${RXDIF_UNIT}" "${RXDIF}"
	return 0
}
