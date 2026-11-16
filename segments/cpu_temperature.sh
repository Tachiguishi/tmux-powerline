# shellcheck shell=bash
# Print CPU package temperature and fan speed using lm-sensors / procfs.

TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL="${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL:-CPU }"
TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL_COLOUR="${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL_COLOUR:-255}"
TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SHOW_FAN="${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SHOW_FAN:-true}"
TMUX_POWERLINE_SEG_CPU_TEMPERATURE_FAN_SYMBOL="${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_FAN_SYMBOL:- }"
TMUX_POWERLINE_SEG_CPU_TEMPERATURE_FAN_UNIT="${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_FAN_UNIT:-RPM}"

generate_segmentrc() {
	read -r -d '' rccontents <<EORC
# Symbol for CPU temperature
# export TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL="${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL}"
# Symbol colour for CPU temperature
# export TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL_COLOUR="${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL_COLOUR}"
# Whether to read and display fan speed: "true" or "false"
# export TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SHOW_FAN="${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SHOW_FAN}"
# Symbol / separator for fan speed
# export TMUX_POWERLINE_SEG_CPU_TEMPERATURE_FAN_SYMBOL="${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_FAN_SYMBOL}"
# Unit for fan speed
# export TMUX_POWERLINE_SEG_CPU_TEMPERATURE_FAN_UNIT="${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_FAN_UNIT}"
EORC
	echo "$rccontents"
}

run_segment() {
	local show_fan="$TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SHOW_FAN"

	# 解析 flag 参数（命令行传参或函数参数优先级高于环境变量）
	while [ $# -gt 0 ]; do
		case "$1" in
			-f|--fan|--show-fan|true|1)
				show_fan="true"
				shift
				;;
			-n|--no-fan|--hide-fan|false|0)
				show_fan="false"
				shift
				;;
			*)
				shift
				;;
		esac
	done

	local temperature
	local fan_speed=""
	local sensors_output=""

	shell_is_linux 2>/dev/null || [ "$(uname -s)" = "Linux" ] || return 1

	if command -v sensors >/dev/null 2>&1; then
		sensors_output=$(sensors 2>/dev/null)
		temperature=$(echo "$sensors_output" | awk '
			/(Package id [0-9]+|Tctl|Tdie|Core [0-9]+)/ {
				if (match($0, /[+-]?[0-9]+([.][0-9]+)?°C/)) {
					value = substr($0, RSTART, RLENGTH)
					gsub(/[+°C]/, "", value)
					printf "%.0f", value
					exit
				}
			}
		')
	fi

	# Fallback for temperature from thermal_zone if sensors failed
	if [ -z "$temperature" ]; then
		for tz in /sys/class/thermal/thermal_zone*/temp; do
			[ -r "$tz" ] || continue
			local raw_temp
			raw_temp=$(cat "$tz" 2>/dev/null)
			if [ -n "$raw_temp" ] && [ "$raw_temp" -gt 0 ]; then
				temperature=$((raw_temp / 1000))
				break
			fi
		done
	fi

	[ -n "$temperature" ] || return 1

	# 仅当启用 show_fan 时，才执行风扇转速的读取逻辑
	if [ "$show_fan" = "true" ] || [ "$show_fan" = "1" ]; then
		# 1. 优先从 /proc/acpi/ibm/fan 读取 (ThinkPad 稳定快速接口)
		if [ -r /proc/acpi/ibm/fan ]; then
			local ibm_fan
			ibm_fan=$(awk '/speed:/ {if ($2 ~ /^[0-9]+$/ && $2 != 65535) print $2}' /proc/acpi/ibm/fan 2>/dev/null)
			[ -n "$ibm_fan" ] && fan_speed="$ibm_fan"
		fi

		# 2. 若未获取到，从 /sys/class/hwmon/*/fan*_input 读取有效转速
		if [ -z "$fan_speed" ]; then
			for f in /sys/class/hwmon/hwmon*/fan*_input; do
				[ -r "$f" ] || continue
				local val
				val=$(cat "$f" 2>/dev/null)
				if [ -n "$val" ] && [ "$val" -gt 0 ] && [ "$val" -lt 65535 ]; then
					fan_speed="$val"
					break
				fi
			done
		fi

		# 3. 若仍未获取到，尝试从 sensors 输出中匹配
		if [ -z "$fan_speed" ] && [ -n "$sensors_output" ]; then
			fan_speed=$(echo "$sensors_output" | awk '
				/fan[0-9]+:/ {
					for (i = 1; i <= NF; i++) {
						if ($i ~ /^[0-9]+$/) {
							rpm = $i + 0
							if (rpm > 0 && rpm < 65535) {
								print rpm
								exit
							}
						}
					}
				}
			')
		fi
	fi

	local fan_str=""
	if [ -n "$fan_speed" ]; then
		fan_str="${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_FAN_SYMBOL}${fan_speed}${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_FAN_UNIT}"
	fi

	echo "#[fg=$TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL_COLOUR]${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL}#[fg=${TMUX_POWERLINE_CUR_SEGMENT_FG:-255}]${temperature}°C${fan_str}"
	return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	run_segment "$@"
fi
