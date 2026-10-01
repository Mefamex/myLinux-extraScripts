#!/usr/bin/env bash
#
# lib/log.sh — sourced file, DO NOT RUN DIRECTLY
#
# This file is `source`d by systemReport.sh. Running it on its own does
# nothing and dies on the variables it expects. The shebang is only there so the
# linter recognises the file as shell.
#
# systemReport — log.sh
#
# The single exit point for console output. Every user-facing line goes through
# here and is written to terminal_log.txt at the same time.
#
# Why not `exec > >(tee -a ...)`:
#   Process substitution makes bash's exit ordering unpredictable (tee has not
#   necessarily flushed by the time the script returns), and it cannot capture
#   the `sudo -v` password prompt, which reads straight from the terminal. One
#   function plus an explicit `>>` is easier to reason about and to test.
#
# Depends on: $LOG_FILE (may be empty until systemReport.sh resolves it)

# Colour is enabled only when stdout is a terminal. The log file never receives
# colour codes, so `grep` and `cat` output stays clean and pasteable.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	C_RESET=$'\033[0m'
	C_DIM=$'\033[2m'
	C_GREEN=$'\033[0;32m'
	C_YELLOW=$'\033[1;33m'
	C_CYAN=$'\033[0;36m'
	C_RED=$'\033[0;31m'
else
	C_RESET='' C_DIM='' C_GREEN='' C_YELLOW='' C_CYAN='' C_RED=''
fi

# Width of the horizontal rules. 64 fits an 80-column terminal with a margin.
RULE_WIDTH=64

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

# Build a rule of a given width without printing '-' in a loop.
#
# `printf '%*s' N ''` pads an empty string to N columns; tr then swaps every
# space for the requested character. Doing it this way keeps the width a single
# number in one place instead of a literal repeated in every rule.
rule_line() {
	local width="${1:-64}" char="${2:--}"
	printf "%${width}s" '' | tr ' ' "$char"
}

# rule [lines] [char] — print a horizontal separator.
#
# One line is too thin to register as a boundary when output is scrolling past,
# so every boundary in this script is at least two lines tall, and the major
# transitions use three. Extra lines cost nothing and make the shape of the run
# readable at a glance.
#
# Colour is decided per CALL, not once at load time: this same function writes
# the log file, and escape codes must never end up there.
rule() {
	local lines="${1:-2}" char="${2:--}" color='' i
	[ -t 1 ] && [ -z "${NO_COLOR:-}" ] && color="$C_DIM"
	local line
	line="$(rule_line "$RULE_WIDTH" "$char")"
	for ((i = 0; i < lines; i++)); do
		printf '%s%s%s\n' "$color" "$line" "$C_RESET"
	done
	return 0
}

# The actual writer. $1 = colour escape, remaining args = the message.
#
# A failure to write the log (permissions, full disk) must not abort the run:
# the collected report files are the real output, the console log is a
# convenience. So the write error is swallowed rather than propagated.
_emit() {
	local color="$1"
	shift
	printf '%s%s%s\n' "$color" "$*" "$C_RESET"
	if [ -n "${LOG_FILE:-}" ] && [ -w "${LOG_FILE:-/nonexistent}" ]; then
		printf '%s\n' "$*" >>"$LOG_FILE" 2>/dev/null ||
			true
	fi
}

ok() { _emit "$C_GREEN" "$*"; }
info() { _emit "$C_CYAN" "$*"; }
warn() { _emit "$C_YELLOW" "$*"; }
err() { _emit "$C_RED" "$*" >&2; }

# A labelled detail line: "Report root : /home/...". The alignment is what makes
# the startup block scannable.
detail() {
	printf '  %-16s : %s\n' "$1" "$2"
}

# Records which file a section wrote to. Without this the console log mentions
# file names with no way to tell what produced them.
section_progress() {
	local number="$1" title="$2" file="$3"
	_emit "$C_DIM" "  -> [$number $title]  $file"
}
