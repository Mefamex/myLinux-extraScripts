#!/usr/bin/env bash
#
# systemReport.sh — Arch Linux system report collector
#
#   ./systemReport.sh                 collect a full report
#   ./systemReport.sh --only 03,04    collect only the storage and graphics sections
#   ./systemReport.sh -o ~/reports   write reports under a different root
#   ./systemReport.sh --version       print the version and its date
#   ./systemReport.sh --help          print this text
#
# Written and maintained by @mefamex.
# Report contents, section list and all comments are in English; nothing in the
# code, the settings or the output is localised on purpose, so the same script
# behaves identically on any machine regardless of locale.
#
# What it does:
#   Collects hardware, network, package, log and configuration state across ten
#   sections. Each section goes to its own file, and everything is then merged
#   into a single flat report. Anything printed to the terminal is also written
#   to terminal_log.txt without colour codes, so the console output is not lost
#   when the terminal scrolls away.
#
# Layout:
#   lib/            infrastructure (config, output, log, sudo, report writing,
#                   cleanup)
#   lib/sections/   one file per section; sections never call each other
#   VERSION         the single source of truth for version and version date
#   config          settings, tracked in the repository (no template needed)
#
# Settings:
#   No personal value is baked into the script. Settings are read from the
#   `config` file next to this script, which is tracked so a fresh clone is
#   immediately runnable. An environment variable overrides the config file:
#     SR_REPORT_ROOT  report root (empty means "resolve automatically")
#     SR_KEEP         how many reports to keep
#     SR_SUDO         0 = skip the checks that need root
#     SR_CLEANUP      0 = do not touch old reports
#     SR_LOG          terminal log path
#     SR_CONFIG       use a different config file
#
set -uo pipefail

# --- where we are ------------------------------------------------------------
#
# Modules are read from the lib/ directory next to the script, so the working
# directory does not matter. BASH_SOURCE is used because $0 is wrong once the
# script is sourced.
_SELF="${BASH_SOURCE[0]}"
_HERE="$(cd -- "$(dirname -- "$_SELF")" 2>/dev/null && pwd)"
unset _SELF

# Fallback author, used only if the VERSION file has no AUTHOR line. Keeping it
# here means the name is written down in exactly one place in the code.
_SCRIPT_AUTHOR='@mefamex'

# Module loader. A missing module is a hard error: a report that silently skips
# data is far worse than one that refuses to start.
_load() {
	if [ ! -r "$_HERE/lib/$1.sh" ]; then
		printf 'error: module not found: %s\n' "$_HERE/lib/$1.sh" >&2
		exit 1
	fi
	# shellcheck source=/dev/null
	. "$_HERE/lib/$1.sh"
}

# version is loaded first: everything else depends on the version string.
# shellcheck source=lib/version.sh
_load version

usage() {
	# Print the leading comment block. A line range (sed -n '2,27p') breaks
	# the moment a line is added to the header; the awk pattern from
	# wifisentinel prints the block up to the first non-comment line instead.
	awk 'NR>1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0"
}

# --- arguments ---------------------------------------------------------------
#
# Each argument is parsed once into its own variable and the main flow only ever
# reads those variables, so the parsing logic is never duplicated.

# REPORT_PREFIX, REPORT_STAMP, USE_SUDO_CHECKS and CLEANUP_ENABLED are read
# inside the lib/ modules rather than here, which the linter cannot see across
# `source`.
# shellcheck disable=SC2034  # REPORT_PREFIX is read in lib/output.sh and lib/cleanup.sh
REPORT_PREFIX='arch_report'
SECTION_FILTER=''
KEEP_OVERRIDE=''
# The root from the command line is kept in a separate variable: the config file
# assigns REPORT_ROOT and would otherwise wipe the argument. Applied after
# load_config, giving the precedence argument > environment > config.
ROOT_OVERRIDE=''
SHOW_HELP=false
SHOW_VERSION=false
NO_SUDO=false
NO_CLEAN=false

# log is loaded BEFORE argument parsing, because invalid-argument paths call
# err/warn and those functions do not exist yet. log.sh has no dependency on
# config (it writes nothing when LOG_FILE is empty), so loading it early does not
# invert any ordering.
# shellcheck source=lib/log.sh
. "$_HERE/lib/log.sh"

while [ $# -gt 0 ]; do
	case "$1" in
	-o | --out-dir)
		# A -o with no value must fail, not silently fall back to the
		# default location.
		[ $# -ge 2 ] || {
			err "'$1' needs a directory."
			exit 1
		}
		ROOT_OVERRIDE="$2"
		shift 2
		;;
	--only)
		[ $# -ge 2 ] || {
			err "--only needs a section list (e.g. --only 03,04)."
			exit 1
		}
		SECTION_FILTER="$2"
		shift 2
		;;
	--keep)
		[ $# -ge 2 ] || {
			err "--keep needs a number."
			exit 1
		}
		KEEP_OVERRIDE="$2"
		shift 2
		;;
	--version | -V)
		SHOW_VERSION=true
		shift
		;;
	--nosudo)
		NO_SUDO=true
		shift
		;;
	--noclean)
		NO_CLEAN=true
		shift
		;;
	-h | --help)
		SHOW_HELP=true
		shift
		;;
	*)
		# A common mistake is writing "./script.sh SR_SUDO=0" instead of
		# "SR_SUDO=0 ./script.sh". Silently ignoring it would leave the
		# user believing the setting applied.
		case "$1" in
		SR_REPORT_ROOT=* | SR_KEEP=* | SR_SUDO=* | SR_CLEANUP=* | SR_LOG=* | SR_CONFIG=*)
			err "'$1' is not an argument, it is an environment variable."
			printf '       correct form:  %s %s\n' "$1" "$0" >&2
			;;
		esac
		err "unknown argument: $1  (--help)"
		exit 2
		;;
	esac
done

if [ "$SHOW_HELP" = true ]; then
	usage
	exit 0
fi

# Called directly rather than in a command substitution: load_version assigns
# VERSION and VERSION_DATE, and report headers read them. In a subshell those
# assignments would be lost.
load_version

if [ "$SHOW_VERSION" = true ]; then
	printf 'systemReport %s\n' "$VERSION_INFO"
	exit 0
fi

# --- remaining modules -------------------------------------------------------
#
# log was already loaded above, before argument parsing. The rest: config
# (decides the settings) -> output (depends on config) -> report writing ->
# cleanup -> sudo.
_load config
_load output
_load report
_load cleanup
_load sudo
unset -f _load

# --- settings ----------------------------------------------------------------
#
# Arguments are layered on top of the config file, which is layered on top of
# the environment: argument > environment > config.

load_config

[ -n "$ROOT_OVERRIDE" ] && REPORT_ROOT="$ROOT_OVERRIDE"
# shellcheck disable=SC2034  # USE_SUDO_CHECKS is read in lib/sudo.sh
[ "$NO_SUDO" = true ] && USE_SUDO_CHECKS=0
# shellcheck disable=SC2034  # CLEANUP_ENABLED is read in lib/cleanup.sh
[ "$NO_CLEAN" = true ] && CLEANUP_ENABLED=0
[ -n "$KEEP_OVERRIDE" ] && KEEP_REPORTS="$KEEP_OVERRIDE"

# --keep is validated here too: config.sh only checks the value coming from the
# config file or the environment, and arguments take the same path.
case "$KEEP_REPORTS" in
'' | *[!0-9]*)
	err "--keep / KEEP_REPORTS must be a number, using 10."
	KEEP_REPORTS=10
	;;
esac
[ "$KEEP_REPORTS" -lt 1 ] && KEEP_REPORTS=1

# Host name. The `hostname` command is part of the `hostname` package and is
# absent on minimal installs, so fall back to bash's $HOSTNAME and then to
# /proc. If all three fail the report says "unknown" and the run continues.
if command -v hostname >/dev/null 2>&1; then
	HOST_NAME="$(hostname 2>/dev/null)"
elif [ -r /proc/sys/kernel/hostname ]; then
	HOST_NAME="$(cat /proc/sys/kernel/hostname 2>/dev/null)"
else
	HOST_NAME="${HOSTNAME:-}"
fi
[ -n "$HOST_NAME" ] || HOST_NAME='unknown'

# shellcheck disable=SC2034  # REPORT_STAMP is read in lib/output.sh
REPORT_STAMP="$(date +%Y%m%d_%H%M%S)"

# --- section registry --------------------------------------------------------
#
# Each entry is number|file name|title. Keeping the registry in one place means
# adding a section touches exactly two files: the section module and this list.
# The section modules themselves only run commands.

SECTIONS=(
	'00|00_privacy.txt|Privacy Notice'
	'01|01_system.txt|Basic System Information'
	'02|02_hardware.txt|Hardware Details'
	'03|03_storage.txt|Storage and Disks'
	'04|04_graphics.txt|Graphics and Display'
	'05|05_network.txt|Network Configuration'
	'06|06_packages.txt|Installed Packages'
	'07|07_logs.txt|System Logs and Errors'
	'08|08_configuration.txt|Configuration Files'
	'09|09_users.txt|Users and Groups'
)

# --only validation: an unknown number is an error, and the list of valid
# numbers is printed. Collecting zero sections because of a typo is the most
# confusing version of "empty report".
if [ -n "$SECTION_FILTER" ]; then
	case ",$SECTION_FILTER," in
	*', '* | *',,'*)
		err "--only has a space or a missing number: '$SECTION_FILTER'"
		err "valid form: --only 03,04   (comma separated, no spaces)"
		exit 1
		;;
	esac

	# Check that a NN_*.sh module actually exists for each number.
	# `test -r` does not expand globs, so the candidates are resolved first.
	_accepted=''
	_all_ok=true
	IFS=',' read -ra _only <<<"$SECTION_FILTER"
	for _no in "${_only[@]}"; do
		case "$_no" in
		[0-9][0-9]) ;;
		*)
			err "invalid section number: '$_no' (two digits, e.g. 03)"
			_all_ok=false
			continue
			;;
		esac
		_found=false
		for _m in "$_HERE/lib/sections/${_no}_"*.sh; do
			[ -r "$_m" ] || continue
			_found=true
			break
		done
		if [ "$_found" = false ]; then
			err "section not found: ${_no}_*  (valid: 00-09)"
			_all_ok=false
			continue
		fi
		_accepted+="${_no},"
	done
	unset _only _no _m _found
	[ "$_all_ok" = true ] || exit 1
	SECTION_FILTER="$_accepted"
fi

# --- sections to run ---------------------------------------------------------
#
# With a filter, only the selected sections are loaded and run; the modules for
# the others are never even read.

section_selected() {
	[ -z "$SECTION_FILTER" ] && return 0
	case "$SECTION_FILTER" in
	*"$1,"*) return 0 ;;
	*) return 1 ;;
	esac
}

# --- start -------------------------------------------------------------------

print_version_banner "$VERSION_INFO" "$AUTHOR"

# The terminal log path is only known after the report root is resolved, so the
# log opens here. Anything printed before this point went to the screen only.
resolve_report_root || exit 1
create_report_dir || exit 1

# The default is per report: the log lands in the report folder that was just
# created, so every report carries its own complete terminal output and a folder
# can be handed over as a unit. An explicit LOG_FILE is one shared file for the
# whole machine, so it appends across runs instead. Appending unconditionally
# covers both cases: a brand new per-report file behaves the same either way.
LOG_FILE="${LOG_FILE:-$REPORT_DIR/terminal_log.txt}"

# A custom LOG_FILE usually points somewhere that does not exist yet. The
# redirect below would fail silently, and _emit skips every write when the file
# is not there — the run would look completely normal while producing no log at
# all. So the directory is created first, and a failure is reported instead of
# being swallowed.
_log_dir="$(dirname -- "$LOG_FILE")"
if [ ! -d "$_log_dir" ] && ! mkdir -p -- "$_log_dir" 2>/dev/null; then
	warn "cannot create the log directory: $_log_dir"
	warn "the terminal log will not be written this run."
elif [ ! -w "$_log_dir" ]; then
	warn "log directory is not writable: $_log_dir"
	warn "the terminal log will not be written this run."
fi
unset _log_dir

# Whether this log already has content is decided BEFORE the block below opens
# it for appending. Testing inside the block would mean stat'ing a file the same
# pipeline is writing (SC2094), and the answer would depend on which side wins.
_log_has_content=false
[ -s "$LOG_FILE" ] && _log_has_content=true

{
	# The run separator only goes in when there is already something above it.
	# A fresh per-report log should start with its own header, not with an
	# empty rule block.
	if [ "$_log_has_content" = true ]; then
		printf '\n'
		rule 2 '='
	fi
	# The version goes into the log header, not only into the report files.
	# The log is the one artefact that gets pasted into a chat message, so it
	# has to say which version produced it without opening the folder first.
	printf 'systemReport %s - terminal log\n' "$VERSION_INFO"
	printf 'Author   : %s\n' "$AUTHOR"
	printf 'Host     : %s\n' "$HOST_NAME"
	printf 'Kernel   : %s\n' "$(uname -r 2>/dev/null)"
	printf 'Started  : %s\n' "$(timestamp)"
	rule 2 '-'
} >>"$LOG_FILE" 2>/dev/null
unset _log_has_content

rule 3
detail 'Report root' "$REPORT_ROOT${ROOT_SOURCE:+  (from: $ROOT_SOURCE)}"
detail 'Report folder' "$REPORT_DIR"
detail 'Terminal log' "$LOG_FILE"
rule 3

# Printed after the paths, not before: a reader who lands on this line needs to
# see where the report went before being told anything else.
[ "$REPORT_DIR_COLLIDED" != false ] &&
	warn "a folder with the same timestamp already existed, using: $REPORT_DIR_COLLIDED"

prepare_sudo

if [ -n "$SECTION_FILTER" ]; then
	# ${var%,} and not ${var%,?}: in shell globbing `?` matches exactly one
	# character, never zero, so `,?` cannot match a trailing comma that has
	# nothing after it and nothing gets stripped.
	warn "Filter active - collecting only: ${SECTION_FILTER%,}"
fi

# --- collect -----------------------------------------------------------------

for _entry in "${SECTIONS[@]}"; do
	IFS='|' read -r _no _file _title <<<"$_entry"
	section_selected "$_no" || continue

	# Locate the module: the registry's number must match the section file
	# name, 03_storage.txt -> 03_storage.sh.
	_module="$_HERE/lib/sections/$(printf '%s' "$_file" | sed 's/\.txt$/.sh/')"
	if [ ! -r "$_module" ]; then
		err "section module missing: $_module"
		continue
	fi

	# The module only defines a function (section_NN); the call happens here.
	# shellcheck source=/dev/null
	. "$_module"
	_fn="section_${_no}"

	if ! declare -F "$_fn" >/dev/null 2>&1; then
		err "$_module does not define $_fn, section skipped."
		continue
	fi

	write_section "$_no" "$_file" "$_title" "$_fn"
	unset -f "$_fn"
done
unset _entry _no _file _title _module _fn

rule 3

# --- results -----------------------------------------------------------------

write_version_stamp
merge_full_report
prune_old_reports
fix_report_ownership

# Summary: which files were produced, and how big they are.
#
# The log's size is read BEFORE the block writes to it. Stat'ing a file that the
# same pipeline is appending to is a race (SC2094): whether the read or the
# write happens first is undefined.
_log_size="$(stat -c %s "$LOG_FILE" 2>/dev/null || printf '0')"
_merged_size="$(stat -c %s "$REPORT_DIR/arch_full_report.txt" 2>/dev/null || printf '?')"
_section_count="$(find "$REPORT_DIR" -maxdepth 1 -name '[0-9][0-9]_*.txt' | wc -l)"
_log_name="$(basename "$LOG_FILE")"

{
	printf '\n'
	rule 3 '-'
	printf 'Section files (%s):\n' "$_section_count"
	find "$REPORT_DIR" -maxdepth 1 -name '[0-9][0-9]_*.txt' -printf '  %f  (%s bytes)\n' 2>/dev/null |
		sort
	printf 'Combined report: arch_full_report.txt  (%s bytes)\n' "$_merged_size"
	printf 'Terminal log   : %s  (%s bytes)\n' "$_log_name" "$_log_size"
	printf '\nFinished: %s\n' "$(timestamp)"
	rule 2 '-'
} >>"$LOG_FILE"
unset _log_size _merged_size _section_count _log_name

rule 3

ok "Collection finished."
detail 'Report folder' "$REPORT_DIR"
detail 'Combined' "$REPORT_DIR/arch_full_report.txt"
detail 'Terminal log' "$LOG_FILE"
detail 'Version' "systemReport $VERSION_INFO"

if [ "$SUDO_OK" -eq 0 ]; then
	warn "Checks needing root were skipped (dmidecode, fdisk, smartctl, dmesg, efibootmgr)."
fi
