#!/usr/bin/env bash
#
# lib/sections/06_packages.sh — sourced file, DO NOT RUN DIRECTLY
#
# systemReport — 06_packages
#
# Inventory of installed software. This answers "what did I install by hand,
# what came from the AUR", which is one of the most requested attachments in a
# bug report.
#
# Depends on: nothing

section_06() {
	if command -v pacman >/dev/null 2>&1; then
		printf -- '\n\n\n--- Package Counts ---\n\n'
		printf 'total      : %s\n' "$(pacman -Q 2>/dev/null | wc -l)"
		printf 'repo       : %s\n' "$(pacman -Qq 2>/dev/null | wc -l)"
		printf 'explicit   : %s\n' "$(pacman -Qqe 2>/dev/null | wc -l)"
		printf 'AUR/foreign: %s\n' "$(pacman -Qqm 2>/dev/null | wc -l)"

		printf '\n\n\n--- Explicitly Installed (pacman -Qe) ---\n\n'
		pacman -Qe 2>/dev/null

		printf '\n\n\n--- AUR / Foreign Packages (pacman -Qm) ---\n\n'
		pacman -Qm 2>/dev/null

		printf '\n\n\n--- Pending Updates ---\n\n'
		checkupdates 2>/dev/null | head -n 40 ||
			printf 'checkupdates not found (package: pacman-contrib).\n'

		printf '\n\n\n--- Last Package Operations ---\n\n'
		if [ -f /var/log/pacman.log ]; then
			grep -E '^\[[0-9-]+ [0-9:]+\] \[PACMAN\] (upgraded|installed|removed)' \
				/var/log/pacman.log 2>/dev/null | tail -n 25
		fi
	else
		printf 'pacman not found - this is not an Arch system.\n'
	fi

	if command -v flatpak >/dev/null 2>&1; then
		printf '\n\n\n--- Flatpak Applications ---\n\n'
		flatpak list --app --columns=application,version,branch 2>/dev/null ||
			printf 'flatpak list could not run.\n'
	else
		printf '\n\n\nflatpak not installed.\n'
	fi

	if command -v pipx >/dev/null 2>&1; then
		printf '\n\n\n--- pipx Applications ---\n\n'
		pipx list --short 2>/dev/null
	fi

	printf '\n\n\n--- Loaded Kernel Modules (first 40) ---\n\n'
	lsmod 2>/dev/null | head -n 40 || echo 'lsmod not found.'
}
