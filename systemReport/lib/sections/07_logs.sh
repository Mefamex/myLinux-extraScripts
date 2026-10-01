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
	printf -- '\n\n\n--- Kernel Log (last 60 lines) ---\n\n'
	if sudo_ready; then
		# -T renders human-readable timestamps.
		sudo -n dmesg -T 2>/dev/null | tail -n 60 ||
			printf 'dmesg could not run.\n'
	else
		note_skipped_privileged 'dmesg (kernel log)'
	fi

	printf '\n\n\n--- Kernel Error and Warning Lines ---\n\n'
	if sudo_ready; then
		sudo -n dmesg -T 2>/dev/null |
			grep -iE '\b(error|fail|warn|timeout|reset)\b' | tail -n 40 ||
			printf 'no matching errors.\n'
	else
		printf 'skipped (needs root)\n'
	fi

	printf '\n\n\n--- Errors From This Boot (journalctl -p 3) ---\n\n'
	# Writing to a temporary file first, instead of discarding stderr, is
	# what makes the difference between "no errors" and "could not read the
	# journal" being distinguishable in the finished report.
	if journalctl -b -p 3 --no-pager -n 100 >/tmp/.sr_journal.$$ 2>/dev/null; then
		cat /tmp/.sr_journal.$$
	else
		printf 'No access to the journal, or it is empty. Tried: journalctl -b -p 3\n'
	fi
	rm -f /tmp/.sr_journal.$$

	printf '\n\n\n--- Tail of the Previous Boot (last 40 lines) ---\n\n'
	journalctl -b -1 -p 0..4 --no-pager -n 40 2>/dev/null |
		head -n 40 || printf 'no record of a previous boot.\n'

	printf '\n\n\n--- Failed Services ---\n\n'
	systemctl --failed --no-pager 2>/dev/null || printf 'could not read.\n'

	printf '\n\n\n--- User Services (systemd --user) ---\n\n'
	systemctl --user --failed --no-pager 2>/dev/null ||
		printf 'no user session, or not accessible.\n'
}
