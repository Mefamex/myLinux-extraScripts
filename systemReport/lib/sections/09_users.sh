#!/usr/bin/env bash
#
# lib/sections/09_users.sh — sourced file, DO NOT RUN DIRECTLY
#
# systemReport — 09_users
#
# Who exists on this machine, who belongs to which group, who logged in last. On
# a shared install this is what puts events on a timeline.
#
# Depends on: nothing

section_09() {
	printf -- '\n\n\n--- Accounts with a Login Shell ---\n\n'
	# Only accounts with a real shell. Service accounts (/usr/bin/nologin) are
	# noise here.
	grep -E '/bin/(ba|z|k|da)?sh$' /etc/passwd 2>/dev/null || printf 'could not read.\n'

	printf '\n\n\n--- Groups of the Current User ---\n\n'
	id 2>/dev/null || printf 'could not read.\n'

	printf '\n\n\n--- Administrator Group Members (wheel/sudo) ---\n\n'
	getent group wheel 2>/dev/null || printf 'no wheel group.\n'
	getent group sudo 2>/dev/null

	printf '\n\n\n--- Recent Logins (last) ---\n\n'
	if command -v last >/dev/null 2>&1; then
		last -n 15 2>/dev/null || printf 'last could not run.\n'
	else
		printf 'last not found (package: util-linux).\n'
	fi

	printf '\n\n\n--- Failed Login Attempts (last 20) ---\n\n'
	if [ -r /var/log/auth.log ] || [ -r /var/log/secure ]; then
		local log='/var/log/auth.log'
		[ -r "$log" ] || log='/var/log/secure'
		grep -iE 'failed password|authentication failure' "$log" 2>/dev/null |
			tail -n 20 || printf 'no matching records.\n'
	else
		printf 'no auth.log (on a journald-based system try: journalctl _COMM=systemd-logind).\n'
	fi

	printf '\n\n\n--- User Services (systemd --user) ---\n\n'
	if command -v systemctl >/dev/null 2>&1; then
		systemctl --user list-units --type=service --no-pager 2>/dev/null |
			head -n 20 || printf 'no user session.\n'
	fi
}
