#!/usr/bin/env bash
#
# lib/sections/07_logs.sh — sourced file, DO NOT RUN DIRECTLY
#
# systemReport — 07_logs
#
# The highest-value section for troubleshooting: kernel errors left over from the
# last boot, warnings in the user journal, units still failing.
#
# dmesg needs root because the kernel ring buffer is restricted. journalctl
# usually works unprivileged if the user is in the systemd-journal group; when
# access is denied the reason is written out rather than leaving a section that
# is silently empty.
#
# Depends on: sudo_ready, note_skipped_privileged (lib/sudo.sh)

section_07() {
	# dmesg is read once and reused by the two blocks below. Reading it twice
	# would be wasteful, and it is the reason the "could not run" case is
	# distinguishable: `dmesg | tail` succeeds whether or not dmesg produced
	# anything, so the pipeline exit code alone never tells the two apart.
	# -T renders human-readable timestamps.
	_klog=''
	_klog_ok=false
	if sudo_ready; then
		if _klog="$(sudo -n dmesg -T 2>/dev/null)"; then
			_klog_ok=true
		fi
	fi

	printf -- '\n\n\n--- Kernel Log (last 60 lines) ---\n\n'
	if ! sudo_ready; then
		note_skipped_privileged 'dmesg (kernel log)'
	elif [ "$_klog_ok" = true ]; then
		printf '%s\n' "$_klog" | tail -n 60
	else
		printf 'dmesg could not run.\n'
	fi

	printf '\n\n\n--- Kernel Error and Warning Lines ---\n\n'
	if ! sudo_ready; then
		note_skipped_privileged 'dmesg error and warning filter'
	elif [ "$_klog_ok" != true ]; then
		printf 'dmesg could not run.\n'
	elif _errs="$(printf '%s\n' "$_klog" |
		grep -iE '\b(error|fail|warn|timeout|reset)\b')"; then
		# grep's own exit code decides this, not the pipeline's: finding no
		# match is a normal exit 1, and appending `|| msg` after a pipeline
		# would never fire because the last command still succeeds.
		printf '%s\n' "$_errs" | tail -n 40
	else
		printf 'no matching errors.\n'
	fi
	unset _klog _klog_ok _errs

	printf '\n\n\n--- Errors From This Boot (journalctl -p 3) ---\n\n'
	# Writing to a temporary file first, instead of discarding stderr, is
	# what makes the difference between "no errors" and "could not read the
	# journal" being distinguishable in the finished report.
	_tmp_j="$(mktemp /tmp/.sr_journal.XXXXXX 2>/dev/null)" || _tmp_j="/tmp/.sr_journal.$$"
	if journalctl -b -p 3 --no-pager -n 100 >"$_tmp_j" 2>/dev/null; then
		cat "$_tmp_j"
	else
		printf 'No access to the journal, or it is empty. Tried: journalctl -b -p 3\n'
	fi
	rm -f "$_tmp_j"

	printf '\n\n\n--- Tail of the Previous Boot (last 40 lines) ---\n\n'
	# journalctl's exit code says whether the previous boot exists at all.
	# `journalctl ... | head` always succeeds, so the message would never
	# print and the section would just be blank.
	if _prev="$(journalctl -b -1 -p 0..4 --no-pager -n 40 2>/dev/null)"; then
		printf '%s\n' "$_prev" | head -n 40
	else
		printf 'no record of a previous boot.\n'
	fi
	unset _prev

	printf '\n\n\n--- Failed Services ---\n\n'
	systemctl --failed --no-pager 2>/dev/null || printf 'could not read.\n'

	printf '\n\n\n--- User Services (systemd --user) ---\n\n'
	systemctl --user --failed --no-pager 2>/dev/null ||
		printf 'no user session, or not accessible.\n'
}
