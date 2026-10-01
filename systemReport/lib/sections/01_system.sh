#!/usr/bin/env bash
#
# lib/sections/01_system.sh — sourced file, DO NOT RUN DIRECTLY
#
# systemReport — 01_system
#
# Which machine this is: kernel, distribution, boot time, session type. This is
# the first thing anyone asks for in a bug report.
#
# Depends on: nothing (system commands only)

section_01() {
	printf -- '\n\n\n--- Host and Kernel ---\n\n'
	hostnamectl 2>/dev/null || uname -a

	printf '\n\n\n--- OS Release ---\n\n'
	cat /etc/os-release 2>/dev/null || echo 'could not read'

	printf '\n\n\n--- Uptime and Load ---\n\n'
	uptime

	printf '\n\n\n--- Kernel Command Line ---\n\n'
	cat /proc/cmdline 2>/dev/null || echo 'could not read'

	printf '\n\n\n--- Virtualization ---\n\n'
	systemd-detect-virt 2>/dev/null || echo 'not virtualized'

	printf '\n\n\n--- Session ---\n\n'
	printf 'Desktop      : %s\n' "${XDG_CURRENT_DESKTOP:-unknown}"
	printf 'Session type : %s\n' "${XDG_SESSION_TYPE:-unknown}"
	printf 'Shell        : %s\n' "${SHELL:-unknown}"

	printf '\n\n\n--- Boot Performance (systemd-analyze) ---\n\n'
	if command -v systemd-analyze >/dev/null 2>&1; then
		systemd-analyze 2>/dev/null
		printf '\n\n\n--- 15 slowest units ---\n\n'
		systemd-analyze blame 2>/dev/null | head -n 15
		printf '\n\n\n--- Critical chain ---\n\n'
		systemd-analyze critical-chain 2>/dev/null | head -n 25
	else
		printf 'systemd-analyze not found.\n'
	fi

	printf '\n\n\n--- Failed Units ---\n\n'
	systemctl --failed --no-pager 2>/dev/null || echo 'could not read'
}
