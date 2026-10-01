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
		# checkupdates exits 2 when there is nothing to upgrade, which is a
		# normal answer, not a failure. Only a missing tool or an unreachable
		# mirror should read as an error. The code is captured in the same
		# statement as the output, so it is not read again later.
		_upd="$(checkupdates 2>/dev/null)"
		_upd_rc=$?
		case "$_upd_rc" in
		0) printf '%s\n' "$_upd" | head -n 40 ;;
		2) printf 'no pending updates.\n' ;;
		*) printf 'checkupdates could not run (package: pacman-contrib).\n' ;;
		esac
		unset _upd _upd_rc

		printf '\n\n\n--- Last Package Operations ---\n\n'
		if [ -f /var/log/pacman.log ]; then
			# The operation lines are tagged [ALPM], not [PACMAN]; [PACMAN]
			# marks the commands pacman itself was invoked with. An earlier
			# pattern required [PACMAN] and a timestamp like "YYYY-MM-DD
			# HH:MM:SS", which matches nothing in a real log: the timestamp
			# is ISO 8601 with an offset and a "T". The tag is matched on its
			# own so the section does not depend on the timestamp format.
			# grep's exit code decides the message, as elsewhere: tail hides
			# "no match" behind its own success, so the result is taken first.
			if _hist="$(grep -E '\[ALPM\] (installed|upgraded|downgraded|reinstalled|removed)' \
				/var/log/pacman.log 2>/dev/null)"; then
				printf '%s\n' "$_hist" | tail -n 25
			else
				printf 'no install/upgrade/remove records in pacman.log.\n'
			fi
			unset _hist
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
	if _mods="$(lsmod 2>/dev/null)"; then
		printf '%s\n' "$_mods" | head -n 40
	else
		printf 'lsmod not found.\n'
	fi
	unset _mods
}
