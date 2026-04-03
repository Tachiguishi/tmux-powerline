# shellcheck shell=bash
# Prints the WAN IP address. The result is cached and updated according to $update_period.
TMUX_POWERLINE_SEG_WAN_IP_SYMBOL="${TMUX_POWERLINE_SEG_WAN_IP_SYMBOL:-ⓦ }"
TMUX_POWERLINE_SEG_WAN_IP_SYMBOL_COLOUR="${TMUX_POWERLINE_SEG_WAN_IP_SYMBOL_COLOUR:-255}"

generate_segmentrc() {
	read -r -d '' rccontents <<EORC
# Symbol for WAN IP
# export TMUX_POWERLINE_SEG_WAN_IP_SYMBOL="${TMUX_POWERLINE_SEG_WAN_IP_SYMBOL}"
# Symbol colour for WAN IP
# export TMUX_POWERLINE_SEG_WAN_IP_SYMBOL_COLOUR="${TMUX_POWERLINE_SEG_WAN_IP_SYMBOL_COLOUR}"
EORC
	echo "$rccontents"
}
run_segment() {
	local tmp_file="${TMUX_POWERLINE_DIR_TEMPORARY}/wan_ip.txt"
	local wan_ip
	local raw_response

	if [ -f "$tmp_file" ]; then
		if shell_is_osx || shell_is_bsd; then
			stat >/dev/null 2>&1 && is_gnu_stat=false || is_gnu_stat=true
			if [ "$is_gnu_stat" == "true" ];then
				last_update=$(stat -c "%Y" ${tmp_file})
			else
				last_update=$(stat -f "%m" ${tmp_file})
			fi
		elif shell_is_linux || [ -z $is_gnu_stat]; then
			last_update=$(stat -c "%Y" ${tmp_file})
		fi

		time_now=$(date +%s)
		update_period=900
		up_to_date=$(echo "(${time_now}-${last_update}) < ${update_period}" | bc)

		if [ "$up_to_date" -eq 1 ]; then
			wan_ip=$(cat ${tmp_file})
		fi
	fi

	if [ -z "$wan_ip" ]; then
		raw_response=$(curl --max-time 2 -s http://myip.ipip.net)

		# raw_response="当前 IP：112.224.167.78  来自于：中国 山东   联通"
		# raw_response="当前 IP：119.191.201.82  来自于：中国 山东 威海  联通"

		if [ "$?" -eq "0" ]; then
			# 提取出： 112.224.167.78(山东-联通)
			wan_ip=$(echo $raw_response | awk -F'：' '{print $2$3}' | awk -F' ' '{printf "%s(%s-%s)\n", $1, $(NF-1), $NF}')

			echo "${wan_ip}" > $tmp_file
		elif [ -f "${tmp_file}" ]; then
			wan_ip=$(cat "$tmp_file")
		fi
	fi

	if [ -n "$wan_ip" ]; then
		echo "#[fg=$TMUX_POWERLINE_SEG_WAN_IP_SYMBOL_COLOUR]${TMUX_POWERLINE_SEG_WAN_IP_SYMBOL}#[fg=$TMUX_POWERLINE_CUR_SEGMENT_FG]${wan_ip}"
	fi

	return 0
}
