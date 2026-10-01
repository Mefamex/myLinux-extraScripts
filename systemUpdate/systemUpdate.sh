#!/usr/bin/env bash
#
# systemUpdate.sh — update Arch Linux and the tools pacman does not own
#
#   ./systemUpdate.sh            system + apps (everything)
#   ./systemUpdate.sh --system   pacman/AUR/firmware/DKMS/.pacnew only
#   ./systemUpdate.sh --apps     npm/VS Code/pipx/uv/... channels only
#   ./systemUpdate.sh --status   CHANGES NOTHING, reports only
#   ./systemUpdate.sh --log      show the most recent log
#   ./systemUpdate.sh --full     UPDATE EVERYTHING, ask no confirmations
#   ./systemUpdate.sh --full --apps  only app channels, no questions
#   ./systemUpdate.sh --full --system  only system steps, no questions
#   ./systemUpdate.sh --help
#
# The full stdout + stderr of every run is written to one file.
# Directory resolves via cascade:
#   ~/Belgeler/systemUpdate → ~/Documents/systemUpdate → ~/systemUpdate → ~/.local/state/systemUpdate
# Two runs in the same minute get -1, -2, ... instead of overwriting each other.
#
# Rules:
#   - EVERY channel asks for confirmation, default no. A channel that is
#     silently skipped is only lost work; a channel that runs by accident
#     cannot be undone.
#   - .pacnew files are NEVER deleted, only listed. They are your own /etc
#     settings; removing them automatically loses them for good.
#   - Nothing destructive ever runs: no `docker system prune`, no `brew cleanup`.
#   - `brew update` never runs: /opt/brew belongs to pacman and brew would
#     `git pull` over it. (brew also has 27 formulae installed, but
#     /opt/brew/bin is not on PATH so none of them are reachable anyway.)
#
# Settings come from the `config` file or from the environment:
#   SYSUPDATE_LOG_DIR=/tmp/log        where logs are written
#   SYSUPDATE_SKIP_CHANNELS="npm go"  channels to skip
#   SYSUPDATE_GO_BIN_DIR=~/go/bin     where `go install` puts binaries
#   SYSUPDATE_LOG_KEEP=50             how many log files to keep
#   SYSUPDATE_STATUS_AUR=1            also query AUR in --status (needs network)
#   SYSUPDATE_CONFIG=/full/path       use a different config file
set -uo pipefail

# --- modules -------------------------------------------------------------
#
# Each module does exactly one job and can be sourced on its own. A missing
# module is a hard error — we never run half a system update silently.

_SELF="${BASH_SOURCE[0]}"
_HERE="$(cd -- "$(dirname -- "$_SELF")" 2>/dev/null && pwd)"
unset _SELF

# Load order does not matter — modules only define functions and never call
# each other. config.sh is still loaded FIRST because the settings below read
# the values it defines.
#
# One module per line (rather than a loop) because a source directive does not
# work inside a conditional loop; this way static analysis also sees them.
_load_module() {
	if [ ! -r "$_HERE/lib/$1.sh" ]; then
		printf 'error: module not found: %s\n' "$_HERE/lib/$1.sh" >&2
		exit 1
	fi
	# shellcheck source=/dev/null
	. "$_HERE/lib/$1.sh"
}

# shellcheck source=lib/config.sh
_load_module config
config_load

# --- remaining modules ---------------------------------------------------
#
# All settings live in lib/config.sh; to find where one is used:
#   grep -rn LOG_KEEP lib/

# shellcheck source=lib/log.sh
_load_module log
# shellcheck source=lib/system.sh
_load_module system
# shellcheck source=lib/status.sh
_load_module status
# shellcheck source=lib/apps.sh
_load_module apps
unset -f _load_module
unset _HERE

# --- arguments -----------------------------------------------------------

SCOPE="all"
FULL_AUTO=0
for arg in "$@"; do
	case "$arg" in
	--system) SCOPE="system" ;;
	--apps) SCOPE="apps" ;;
	--status) SCOPE="status" ;;
	--log) SCOPE="log" ;;
	# "all" is already the default; spelled out so it can also be used as the
	# script name in examples.
	--all | --everything) SCOPE="all" ;;
	# Update everything without asking. Still respects SKIP_CHANNELS and
	# not-installed channels; it only skips the [y/N] confirmations.
	--full)
		FULL_AUTO=1
		;;
	-h | --help)
		# Print only the leading comment block (up to the first non-comment
		# line). Not tied to line numbers, so adding lines cannot break it.
		awk 'NR>1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0"
		exit 0
		;;
	*)
		# Common mistake: writing "systemUpdate.sh SYSUPDATE_LOG_DIR=..."
		# instead of "SYSUPDATE_LOG_DIR=... systemUpdate.sh". Catch it.
		case "$arg" in
		SYSUPDATE_*=*)
			printf "warning: '%s' is an env var, not an argument.\n" "$arg" >&2
			printf '         correct form:  %s %s\n' "$arg" "$0" >&2
			;;
		esac
		printf 'unknown argument: %s  (--help)\n' "$arg" >&2
		exit 2
		;;
	esac
done

# --- log mode (file or screen) -------------------------------------------

_latest_log() {
	# zsh glob qualifiers do not exist here; in bash it is ls -t + head. The
	# `ls` alias only expands in an interactive shell, so it is not expanded
	# when the script runs — but it could be if the script were sourced, hence
	# the absolute /bin/ls.
	/bin/ls -t -- "$LOG_DIR"/*.txt 2>/dev/null | head -1
}

if [ "$SCOPE" = "log" ]; then
	f=$(_latest_log)
	if [ -n "$f" ]; then
		printf 'latest log: %s\n\n' "$f"
		${PAGER:-less} "$f"
	else
		printf 'No logs yet: %s\n' "$LOG_DIR"
	fi
	exit 0
fi

# --status never changes anything. Setting REPORT_ONLY=1 makes confirm() always
# answer "no", so no separate branch is needed in the flow and every reported
# channel travels the exact same code path (one path = one source of truth).
REPORT_ONLY="${REPORT_ONLY:-0}"
FULL_AUTO="${FULL_AUTO:-0}"
export REPORT_ONLY FULL_AUTO
if [ "$SCOPE" = "status" ]; then
	REPORT_ONLY=1
fi

if ! log_open "systemUpdate"; then
	# If the log cannot be opened we do NOT run the update. Updating a live
	# system with no record of what happened means a failure cannot be
	# diagnosed afterwards.
	printf 'error: could not open the log, refusing to start.\n' >&2
	exit 1
fi

# --- clean shutdown ------------------------------------------------------
#
# Signal trap. `trap -` MUST come first: if log_close's `wait` takes a second
# signal, the trap re-enters the same function, the script never exits and
# spins forever. Clearing the trap turns the second signal back into normal
# flow, and the following `exit` really terminates.
#
# MEASURED: without the exit, Ctrl+C closed the log but did NOT stop the script
# — the next step kept running and the script exited with rc=0. The user
# believed they had cancelled while updates silently continued.
_shutdown() {
	local sig="${1:-0}"
	trap - INT TERM EXIT
	log_close "$sig"
	exit "$sig"
}
trap '_shutdown 130' INT
trap '_shutdown 143' TERM
trap '_shutdown $?' EXIT

# --- flow ----------------------------------------------------------------

rc=0
case "$SCOPE" in
status)
	# System is reported too, so --status keeps its promise.
	system_status
	apps_update
	;;
system)
	system_update || rc=1
	;;
apps)
	apps_update
	;;
all)
	# System first, apps second. The system step can upgrade the kernel and
	# node/npm; the app channels are built on top of those, so updating apps
	# first would upgrade them onto the old versions.
	if system_update; then
		apps_update
	else
		warn "System update stopped early; skipping the app channels."
		rc=1
	fi
	;;
esac

exit $rc
