#!/usr/bin/env bash
#
# lib/status.sh — source file, NOT meant to be run directly
#
# systemUpdate — status.sh
#
# READ-ONLY reporting. Nothing in this file writes to the system, installs
# anything or touches a config. Compare lib/system.sh, which is the opposite.
#
# Depends on: section/warn/info (lib/log.sh), $STATUS_AUR (lib/config.sh)

# system_status  →  read-only summary of the system side
system_status() {
	local out n rc=0

	section "System: pending package updates"
	# `pacman -Qu` is MISLEADING: it only reflects the last sync, so a stale
	# database makes everything look current. checkupdates builds a throwaway
	# database and reads that, so it tells the truth.
	if command -v checkupdates >/dev/null 2>&1; then
		out=$(checkupdates 2>/dev/null)
		n=$(printf '%s' "$out" | grep -c . || true)
		if [ "$n" -eq 0 ]; then
			# checkupdates queries the OFFICIAL repos only (throwaway
			# database + SyncExcludes). It does NOT cover the AUR, so the
			# message says exactly that instead of claiming everything is
			# current. The AUR is opt-in via STATUS_AUR=1 below.
			info "official repositories are current — the AUR is NOT included"
			_aur_status
		else
			# Printed in full. This list really can be long (300 pending
			# packages after a few months away) and every line is a package
			# that will actually change, so there is nothing to hide.
			printf '%s\n' "$out" | sed 's/^/      /'
			_aur_status
		fi
	else
		info "checkupdates is not available (pacman-contrib is not installed)"
	fi

	section "System: firmware"
	# Same trap as in lib/system.sh: fwupd prints its "devices without
	# updates" list even when there is nothing to do (23 lines on this
	# machine), so only rc=0 is meaningful.
	if ! command -v fwupdmgr >/dev/null 2>&1; then
		info "fwupd is not installed"
	else
		if out=$(fwupdmgr get-updates 2>&1); then
			rc=0
		else
			rc=$?
		fi
		if [ "$rc" -eq 2 ]; then
			info "current (no update available)"
		elif [ "$rc" -eq 0 ]; then
			printf '%s\n' "$out" | sed 's/^/      /'
		else
			warn "could not query firmware (rc=$rc)"
		fi
	fi

	section "System: DKMS modules"
	if ! command -v dkms >/dev/null 2>&1; then
		info "dkms is not installed"
	else
		out=$(dkms status 2>/dev/null)
		if [ -z "$out" ]; then
			info "no DKMS modules"
		elif printf '%s\n' "$out" | grep -qv installed; then
			printf '%s\n' "$out" | sed 's/^/    /'
			warn "unbuilt DKMS modules present; rebuild with:  sudo dkms autoinstall"
		else
			info "all built"
			printf '%s\n' "$out" | sed 's/^/    /'
		fi
	fi

	section "System: pending .pacnew / .pacsave files"
	# Listed only. Deleting them automatically would lose your /etc settings
	# for good, so this tool never removes them.
	# /usr/bin/find is absolute on purpose — see lib/system.sh for why.
	out=$(/usr/bin/find /etc \( -name '*.pacnew' -o -name '*.pacsave' \) 2>/dev/null)
	if [ -n "$out" ]; then
		printf '%s\n' "$out" | sed 's/^/    /'
		info "to review them:  sudo pacdiff"
	else
		info "none pending"
	fi
}

# _aur_status
#
# AUR coverage for --status, OPT-IN via STATUS_AUR=1.
#
# Why it is not on by default: yay has to fetch the AUR git repository, which
# turns a fast, offline glance into a network operation that can take seconds
# or hang on a bad connection. --status promises to be quick and read-only, so
# the AUR check is a deliberate opt-in rather than a surprise.
#
# Note that yay -Qua still cannot be a *complete* answer either: an AUR
# package with no maintainer (an orphan) is simply not in the AUR at all and
# no query will report it.
_aur_status() {
	local out n

	[ "${STATUS_AUR:-0}" = 1 ] || return 0

	if ! command -v yay >/dev/null 2>&1; then
		info "AUR: yay is not installed, cannot check"
		return 0
	fi

	out=$(yay -Qua 2>/dev/null)
	n=$(printf '%s' "$out" | grep -c . || true)
	if [ "$n" -eq 0 ]; then
		info "AUR: up to date (note: orphaned AUR packages are not covered)"
		return 0
	fi
	printf '%s\n' "$out" | sed 's/^/      /'
	return 0
}
