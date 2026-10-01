#!/usr/bin/env bash
#
# lib/log.sh — source file, NOT meant to be run directly
#
# systemUpdate — log.sh
#
# The layer that writes output to the screen AND to a file. Everything the
# script prints passes through here:
#   log_open  → redirect stdout+stderr into a FIFO; a background tee reads it
#               and writes to both the terminal and the log file
#   log_close → restore the fds, WAIT for tee, prune old logs
#
# Why a FIFO and why not `exec > >(tee file)`:
# In bash, process substitution runs ASYNCHRONOUSLY. MEASURED: with `>(tee f)`
# the log file sometimes did not exist yet by the time the script exited (2 of 5
# runs produced a truncated file). The same pattern was reliable 30/30 in zsh,
# but this script is bash. With a FIFO plus `wait` the file was complete before
# the script exited 20/20 times. Without the `wait` the same pattern was broken.
#
# Depends on: $LOG_DIR, $LOG_KEEP (lib/config.sh)

LOG=""
LOG_LABEL=""
LOG_START=""
_TEE_PID=""
_FIFO=""

# resolve_log_dir
#
# If LOG_DIR is already set (from config or env), use it as-is.
# Otherwise, resolve a sensible log directory via a cascade similar to
# systemReport's resolve_report_root():
#   1. xdg-user-dir DOCUMENTS       -> localized Documents (e.g. Belgeler)
#   2. ~/.config/user-dirs.dirs     -> XDG_DOCUMENTS_DIR
#   3. English names                -> $HOME/Documents, $HOME/Document
#   4. Home backup (not hidden)     -> $HOME/systemUpdate
#   5. XDG state dir (last resort)  -> ${XDG_STATE_HOME:-$HOME/.local/state}/systemUpdate
#
# Each candidate is tested for writability. An explicit LOG_DIR is created
# if missing and checked for write access, rather than failing later.
resolve_log_dir() {
	if [ -n "$LOG_DIR" ]; then
		# Explicit path from config/env. Create and verify writable.
		if ! mkdir -p -- "$LOG_DIR" 2>/dev/null || [ ! -w "$LOG_DIR" ]; then
			printf 'error: log directory not writable: %s\n' "$LOG_DIR" >&2
			return 1
		fi
		return 0
	fi

	# 1. xdg-user-dir: returns the user's real documents directory.
	if command -v xdg-user-dir >/dev/null 2>&1; then
		local candidate
		candidate="$(xdg-user-dir DOCUMENTS 2>/dev/null)"
		if [ -n "$candidate" ] && [ "$candidate" != "$HOME" ] && [ -d "$candidate" ]; then
			LOG_DIR="$candidate/systemUpdate"
			if mkdir -p -- "$LOG_DIR" 2>/dev/null && [ -w "$LOG_DIR" ]; then
				return 0
			fi
		fi
	fi

	# 2. user-dirs.dirs: fallback when xdg-user-dir is missing or unhelpful.
	if [ -r "$HOME/.config/user-dirs.dirs" ]; then
		# shellcheck disable=SC1091
		. "$HOME/.config/user-dirs.dirs" 2>/dev/null || true
		local candidate="${XDG_DOCUMENTS_DIR:-}"
		candidate="${candidate/#\$HOME/$HOME}"
		unset XDG_DOCUMENTS_DIR
		if [ -n "$candidate" ] && [ -d "$candidate" ]; then
			LOG_DIR="$candidate/systemUpdate"
			if mkdir -p -- "$LOG_DIR" 2>/dev/null && [ -w "$LOG_DIR" ]; then
				return 0
			fi
		fi
	fi

	# 3. English names: consistent on otherwise unusual systems.
	for candidate in "$HOME/Documents" "$HOME/Document"; do
		if [ -d "$candidate" ]; then
			LOG_DIR="$candidate/systemUpdate"
			if mkdir -p -- "$LOG_DIR" 2>/dev/null && [ -w "$LOG_DIR" ]; then
				return 0
			fi
		fi
	done

	# 4. Backup inside the home directory. Not hidden; easy to find.
	LOG_DIR="$HOME/systemUpdate"
	if mkdir -p -- "$LOG_DIR" 2>/dev/null && [ -w "$LOG_DIR" ]; then
		return 0
	fi

	# 5. Last resort: XDG state dir. Always exists, not localized.
	LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/systemUpdate"
	if mkdir -p -- "$LOG_DIR" 2>/dev/null && [ -w "$LOG_DIR" ]; then
		return 0
	fi

	printf 'error: could not create any log directory\n' >&2
	return 1
}

# log_open <label>
#
# The label becomes the start of the file name: <label>YYYY-MM-DD-HH-MM.txt
log_open() {
	LOG_LABEL="$1"

	# Resolve LOG_DIR if not already resolved. Done here (not in config_load)
	# so that xdg-user-dir runs in the user's environment, not at source time.
	if [ -z "$LOG_DIR" ] || [ "${_LOG_DIR_RESOLVED:-0}" -eq 0 ]; then
		resolve_log_dir || return 1
		_LOG_DIR_RESOLVED=1
	fi

	local d="$LOG_DIR" f

	# The directory is already created and verified by resolve_log_dir()

	# Two runs in the same minute (two terminals, a test) must not overwrite
	# each other.
	#
	# The classic `[ -e "$f" ]` LOOP RACES: if three processes start at once,
	# all three check while the file does not exist yet, all three pick the
	# SAME name, and two of them silently ERASE the third one's log.
	# MEASURED: 3 parallel runs left 1 file instead of 3; two records lost.
	#
	# Fix: do not pick a name, RESERVE it atomically. A `>` redirection under
	# `set -o noclobber` FAILS if the file exists — instead of asking "does it
	# exist?" we say "try to create it", and a race becomes impossible.
	f="$d/${LOG_LABEL}$(date +%Y-%m-%d-%H-%M).txt"
	local f0="${f%.txt}" i=1
	while ! (set -o noclobber && : >"$f") 2>/dev/null; do
		f="${f0}-$i.txt"
		i=$((i + 1))
		# If the directory is not writable this would loop forever.
		[ "$i" -le 999 ] || {
			printf 'error: could not find a free log name: %s\n' "$f0" >&2
			return 1
		}
	done
	# The reservation left an empty file; tee is about to write into it.

	_FIFO="${TMPDIR:-/tmp}/.systemUpdate-tee-$$-$RANDOM"
	if ! mkfifo "$_FIFO" 2>/dev/null; then
		printf 'error: could not create the temporary FIFO: %s\n' "$_FIFO" >&2
		return 1
	fi

	# ORDER MATTERS: tee opens first (it blocks on the reading end of the
	# FIFO), then the writing end is opened and both sides unblock.
	tee "$f" <"$_FIFO" &
	_TEE_PID=$!

	exec 9>&1
	exec >"$_FIFO" 2>&1

	LOG="$f"
	LOG_START=$(date +%s)

	# Header: who, when, which machine, which kernel.
	printf '### %s started | %s | %s | kernel %s\n' \
		"$LOG_LABEL" "$(date '+%Y-%m-%d %H:%M:%S')" "$(uname -n)" "$(uname -r)"
	printf '    -> log: %s\n' "$f"
	return 0
}

# log_close [rc]
#
# Idempotent: if log_open was never called (--help, an argument error) this
# touches nothing. The main script's EXIT trap calls it too, so running it
# twice has to be harmless.
log_close() {
	local rc="${1:-0}"
	[ -n "$LOG" ] || return 0

	local sn=0
	[ -n "$LOG_START" ] && sn=$(($(date +%s) - LOG_START))
	printf '### %s finished | %s seconds | rc=%s\n' "$LOG_LABEL" "$sn" "$rc"

	# Order matters: close the writing end first (so tee sees EOF and stops),
	# then wait for it. Without the `wait` the file was left truncated.
	exec 1>&9 2>&9 9>&-

	# Unlink the FIFO BEFORE waiting. `wait` depends on tee seeing EOF, and
	# tee only sees EOF once every writing process has closed its end. If a
	# half-finished child (an interrupted npm, say) still holds the FIFO open,
	# `wait` hangs and the script never reaches this point on SIGINT — the
	# FIFO was left behind in /tmp. unlink does not affect OPEN file
	# descriptors: it removes the path, the stream keeps flowing.
	rm -f "$_FIFO" 2>/dev/null

	# Now wait: the FIFO path is gone, so tee is guaranteed to see EOF.
	wait "$_TEE_PID" 2>/dev/null

	# Pruning happens last, once this run's file is complete. It runs after
	# the fds are restored, so its output goes to the terminal, not into a log
	# that is already closed.
	log_prune

	LOG=""
	_TEE_PID=""
	_FIFO=""
}

# log_prune
#
# Keep only the newest LOG_KEEP log files. This is the ONLY place in the tool
# that deletes anything, and it only ever removes log files written by us —
# never a package, never a config, never a .pacnew.
log_prune() {
	local keep="${LOG_KEEP:-50}" f removed=0

	# Anything non-numeric or < 1 means "keep everything"; a typo in the
	# config must never be read as "delete all logs".
	case "$keep" in
	'' | *[!0-9]*) return 0 ;;
	esac
	[ "$keep" -ge 1 ] || return 0

	# `ls -1t` is newest first, so everything from position keep+1 onwards is
	# surplus. `ls` only lists the files matching our own label prefix, so
	# unrelated files in the same directory are untouched.
	while IFS= read -r f; do
		[ -n "$f" ] || continue
		rm -f -- "$f" 2>/dev/null && removed=$((removed + 1))
	done <<EOF
$(/bin/ls -1t -- "$LOG_DIR"/"${LOG_LABEL}"*.txt 2>/dev/null | tail -n "+$((keep + 1))")
EOF

	[ "$removed" -gt 0 ] && printf '  -> pruned %s old log(s), keeping %s\n' "$removed" "$keep"
	return 0
}

# --- output formatting ---------------------------------------------------

# section <title>
#
# Section header followed by THREE blank lines. The blank lines are what makes
# the output readable: before, a step header was immediately followed by its
# own result and the next header appeared right after, so consecutive steps
# ran together (MEASURED on a real run: "[3/5] Firmware" and "[4/5] DKMS" had a
# single blank line between them).
section() {
	printf '\n================================\n'
	printf '==> %s\n' "$*"
	printf '================================\n'
	printf '\n\n\n'
}

warn() {
	printf '  !! %s\n' "$*"
}

info() {
	printf '  -> %s\n' "$*"
}

# In report mode (--status) confirmations are never asked.
REPORT_ONLY="${REPORT_ONLY:-0}"

# confirm <question>  →  0=yes, 1=no/skip, 2=defer, 3=update-all, 4=quit
#
# Default is NO. A skipped channel is only lost work, but a channel that runs
# by accident cannot be undone.
#
# Extended options (used by apps_update but not system_update):
#   a  defer: skip now, but run LAST after all other channels are done
#   A  update-all: run this channel plus every remaining channel without
#      asking again
#   q  quit: abort the whole run immediately
confirm() {
	local question="$1" answer=""
	if [ "$REPORT_ONLY" = 1 ]; then
		return 1
	fi
	if [ ! -t 0 ]; then
		printf '    (no interaction, skipping)\n'
		return 1
	fi
	read -r -p "    $question [y/N/a/A/q] " answer
	# a (defer) and A (update-all+remaining) are distinct:
	# lowercase a defers this channel only, uppercase A updates this plus
	# all remaining channels without asking again.
	case "$answer" in
	y | Y | yes | Yes | YES) return 0 ;;
	a) return 2 ;;            # defer after remaining channels
	A) return 3 ;;            # this + remaining channels
	q | Q | quit) return 4 ;; # abort
	*) return 1 ;;
	esac
}

# report <command or @function>
#
# Runs the command and prints it indented, in full. There is deliberately no
# line cap: the cap this replaced only ever fired on the VS Code channel, and it
# was covering up a report that printed the whole 164-extension inventory
# instead of the 27 extensions that actually had a newer version. That report
# is fixed in _code_report, so the lines that reach the screen now all carry
# information. See lib/apps.sh.
#
# The input comes from the channel table (lib/apps.sh), never from the user.
#
# Routed through `_run` because a table cell can be a plain command
# (`npm -g update`) or an @function (`@_go_report`). A plain `eval` here would
# make @functions fail with "command not found" and the channel would silently
# report "nothing to update" — no visible error, just a wrong report.
report() {
	local command="$1" out
	out=$(_run "$command" 2>/dev/null)
	if [ -z "${out//[[:space:]]/}" ]; then
		printf '      (nothing to update)\n'
		return 0
	fi
	printf '%s\n' "$out" | sed 's/^/      /'
	return 0
}

# _run <input>
#
# A table cell is either a command line or a function name marked with "@".
# The "@" makes the distinction explicit; a bare command could also start with
# an underscore, which would be ambiguous.
_run() {
	case "$1" in
	@*) "${1#@}" ;;
	*) eval "$1" ;;
	esac
}
