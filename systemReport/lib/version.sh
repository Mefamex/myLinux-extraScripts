#!/usr/bin/env bash
#
# lib/version.sh — sourced file, DO NOT RUN DIRECTLY
#
# This file is `source`d by systemReport.sh. Running it on its own does
# nothing and dies on the variables it expects. The shebang is only there so the
# linter recognises the file as shell.
#
# systemReport — version.sh
#
# ../VERSION is the single source of truth. No version number is written
# anywhere else; it is read here and displayed from here.
#
# load_version() prints nothing and only assigns variables. That is deliberate:
# if it were called inside a command substitution ($(load_version)) it would run
# in a subshell, and the VERSION / VERSION_DATE it sets would never reach the
# parent. Report headers need those variables, so the call happens in the main
# shell.
#
# Depends on: $_HERE (computed by systemReport.sh), the VERSION file
#
# Variables it sets:
#   VERSION        "5.0.0"
#   VERSION_DATE   "2026-10-01"
#   AUTHOR         "@mefamex"
#   VERSION_INFO   "5.0.0 (2026-10-01)"

load_version() {
	if [ ! -r "$_HERE/VERSION" ]; then
		printf 'error: VERSION file not found: %s\n' "$_HERE/VERSION" >&2
		printf '       a report cannot be produced without a version.\n' >&2
		exit 1
	fi

	# shellcheck source=/dev/null
	. "$_HERE/VERSION"

	if [ -z "${VERSION:-}" ] || [ -z "${VERSION_DATE:-}" ]; then
		printf 'error: VERSION file is malformed (VERSION / VERSION_DATE missing): %s\n' \
			"$_HERE/VERSION" >&2
		exit 1
	fi

	# Cheap sanity check. A missing quote or a stray edit in VERSION shows up
	# here instead of somewhere in the middle of a report header.
	case "$VERSION" in
	[0-9]*.[0-9]*.[0-9]*) ;;
	*)
		printf 'warning: VERSION in VERSION does not look like x.y.z: %s\n' "$VERSION" >&2
		;;
	esac

	# AUTHOR is optional: a report without it is still a valid report, so its
	# absence is normal rather than fatal.
	AUTHOR="${AUTHOR:-$_SCRIPT_AUTHOR}"

	# shellcheck disable=SC2034  # VERSION_INFO is read by systemReport.sh and lib/report.sh
	VERSION_INFO="$VERSION ($VERSION_DATE)"
}

# Startup banner. This is where the version and its date first show up.
#
# The box width is derived from the longest of the two lines rather than
# hardcoded, so a future "10.0.0" does not break the alignment and nobody has
# to come back and adjust a magic number by hand.
print_version_banner() {
	local v="$1"
	local author="${2:-}"
	local line1 line2 line3 gen pad

	line1="systemReport $v"
	line2="Arch Linux system report collector"
	line3="written by $author"

	# Inner width: longest line plus one space on each side.
	gen=$(((${#line1} > ${#line2} ? ${#line1} : ${#line2}) + 2))
	[ "${#line3}" -gt "$gen" ] && gen=$((${#line3} + 2))
	pad=$((gen - 2))

	printf '\n'
	printf '  +%s+\n' "$(rule_line "$gen" '-')"
	printf '  | %-*s |\n' "$pad" "$line1"
	printf '  | %-*s |\n' "$pad" "$line2"
	printf '  | %-*s |\n' "$pad" "$line3"
	printf '  +%s+\n' "$(rule_line "$gen" '-')"
	printf '\n'
}
