# shellcheck shell=bash
# Print CPU package temperature using lm-sensors.

TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL="${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL:-CPU }"
TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL_COLOUR="${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL_COLOUR:-255}"

generate_segmentrc() {
	read -r -d '' rccontents <<EORC
# Symbol for CPU temperature
# export TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL="${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL}"
# Symbol colour for CPU temperature
# export TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL_COLOUR="${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL_COLOUR}"
EORC
	echo "$rccontents"
}

run_segment() {
	local temperature

	shell_is_linux || return 1
	command -v sensors >/dev/null 2>&1 || return 1

	temperature=$(sensors 2>/dev/null | awk '
		/(Package id [0-9]+|Tctl|Tdie|Core [0-9]+)/ {
			if (match($0, /[+-]?[0-9]+([.][0-9]+)?°C/)) {
				value = substr($0, RSTART, RLENGTH)
				gsub(/[+°C]/, "", value)
				printf "%.0f", value
				exit
			}
		}
	')

	[ -n "$temperature" ] || return 1

	echo "#[fg=$TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL_COLOUR]${TMUX_POWERLINE_SEG_CPU_TEMPERATURE_SYMBOL}#[fg=$TMUX_POWERLINE_CUR_SEGMENT_FG]${temperature}°C"
	return 0
}
