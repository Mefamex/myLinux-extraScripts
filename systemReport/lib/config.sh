#!/usr/bin/env bash
#
# lib/config.sh — sourced file, DO NOT RUN DIRECTLY
#
# This file is `source`d by systemReport.sh. Running it on its own does
# nothing and dies on the variables it expects. The shebang is only there so the
# linter recognises the file as shell.
#
# systemReport — config.sh
#
# Settings loading. No personal value is baked into the script: everything comes
# from the tracked `config` file or from the environment. The environment
# overrides the config file, and systemReport.sh layers arguments on top of both.
#
# Search order:
#   <script dir>/config           default
#   SR_CONFIG=/full/path          point at a different file
#
# Recognised settings (plain NAME=VALUE lines in the config file):
#   REPORT_ROOT      Parent directory for report folders. Empty means "resolve
#                    automatically" (see lib/output.sh). Each run creates a new
#                    <REPORT_ROOT>/arch_report_<timestamp>/ folder.
#   KEEP_REPORTS     How many reports to keep (default 10). Extra ones are deleted.
#   USE_SUDO_CHECKS  1 = run the root-only checks, 0 = skip them.
#   CLEANUP_ENABLED  1 = prune old reports, 0 = leave everything alone.
#   LOG_FILE         Terminal log path. Empty means <report folder>/terminal_log.txt
#
# Depends on: $_HERE (computed by systemReport.sh), $LOG_FILE (may be unset)

load_config() {
	local config_file=''

	if [ -n "${SR_CONFIG:-}" ]; then
		config_file="$SR_CONFIG"
	elif [ -r "$_HERE/config" ]; then
		config_file="$_HERE/config"
	fi

	if [ -n "$config_file" ] && [ -r "$config_file" ]; then
		# shellcheck source=/dev/null
		. "$config_file"
	elif [ -n "$config_file" ]; then
		warn "config file not readable, built-in defaults are used: $config_file"
	else
		warn "no config file found, built-in defaults are used (expected: $_HERE/config)"
	fi

	# --- environment variables override the config file -------------
	[ -n "${SR_REPORT_ROOT:-}" ] && REPORT_ROOT="$SR_REPORT_ROOT"
	[ -n "${SR_KEEP:-}" ] && KEEP_REPORTS="$SR_KEEP"
	[ -n "${SR_LOG:-}" ] && LOG_FILE="$SR_LOG"
	[ -n "${SR_SIZE_CAP:-}" ] && SECTION_SIZE_CAP="$SR_SIZE_CAP"

	# Accept a few spellings for booleans so `SR_SUDO=no` and `SR_SUDO=0` both
	# mean the same thing.
	case "${SR_SUDO:-}" in
	0 | false | no | off) USE_SUDO_CHECKS=0 ;;
	1 | true | yes | on) USE_SUDO_CHECKS=1 ;;
	esac

	case "${SR_CLEANUP:-}" in
	0 | false | no | off) CLEANUP_ENABLED=0 ;;
	1 | true | yes | on) CLEANUP_ENABLED=1 ;;
	esac

	case "${SR_GZIP:-}" in
	0 | false | no | off) GZIP_OLD_REPORTS=0 ;;
	1 | true | yes | on) GZIP_OLD_REPORTS=1 ;;
	esac

	# --- defaults and validation ------------------------------------
	#
	# Every default below is mandatory, not optional. The script runs under
	# `set -u`, and the shipped config leaves REPORT_ROOT and LOG_FILE
	# commented out, so those two may legitimately be unassigned here. An
	# empty-but-defined value is fine; an undefined one aborts at the first read.
	#
	# REPORT_ROOT and LOG_FILE are intentionally left empty: empty means
	# "resolve it for me" (see lib/output.sh and systemReport.sh).
	# shellcheck disable=SC2034  # REPORT_ROOT is read in lib/output.sh
	REPORT_ROOT="${REPORT_ROOT:-}"
	# shellcheck disable=SC2034  # LOG_FILE is read in lib/log.sh
	LOG_FILE="${LOG_FILE:-}"
	KEEP_REPORTS="${KEEP_REPORTS:-10}"
	USE_SUDO_CHECKS="${USE_SUDO_CHECKS:-1}"
	CLEANUP_ENABLED="${CLEANUP_ENABLED:-1}"
	# SECTION_SIZE_CAP is KB; 0 means no cap. Read in lib/report.sh.
	SECTION_SIZE_CAP="${SECTION_SIZE_CAP:-0}"
	# GZIP_OLD_REPORTS: 1 = gzip reports beyond KEEP_REPORTS instead of
	# deleting them. Read in lib/cleanup.sh.
	GZIP_OLD_REPORTS="${GZIP_OLD_REPORTS:-0}"

	# A non-numeric KEEP_REPORTS would make the cleanup arithmetic fail later
	# with a confusing error. Catch it here, where the message can name the
	# setting that is wrong.
	case "$KEEP_REPORTS" in
	'' | *[!0-9]*)
		warn "KEEP_REPORTS is not a number ('$KEEP_REPORTS'), using 10."
		KEEP_REPORTS=10
		;;
	esac
	# Zero would delete the report that was just collected, including the one
	# the user is looking at. One is the smallest value that still makes sense.
	[ "$KEEP_REPORTS" -lt 1 ] && KEEP_REPORTS=1

	# A negative or non-numeric size cap would break the truncation
	# arithmetic. Zero means "no cap", which is the default.
	case "$SECTION_SIZE_CAP" in
	'' | *[!0-9]*)
		warn "SECTION_SIZE_CAP is not a number ('$SECTION_SIZE_CAP'), using 0 (no cap)."
		SECTION_SIZE_CAP=0
		;;
	esac
}
