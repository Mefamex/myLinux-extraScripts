#!/usr/bin/env bash
#
# lib/sections/08_configuration.sh — sourced file, DO NOT RUN DIRECTLY
#
# systemReport — 08_configuration
#
# System settings that were edited by hand: mounts, package resolver,
# initramfs, locale, environment variables, bootloader kernel line, modprobe
# rules.
#
# For a customised system, this section is the answer to "what did I change".
#
# WARNING: /etc/environment may contain API keys or passwords. fstab UUIDs and
# modprobe rules are not shareable either.
#
# Depends on: sudo_ready, note_skipped_privileged (lib/sudo.sh)

section_08() {
	printf -- '\n\n\n--- /etc/fstab ---\n\n'
	cat /etc/fstab 2>/dev/null || printf 'could not read.\n'

	printf '\n\n\n--- /etc/pacman.conf (comments removed) ---\n\n'
	# Repositories and Mirrorlist: the most frequently hand-edited setting.
	grep -vE '^\s*#|^\s*$' /etc/pacman.conf 2>/dev/null || printf 'could not read.\n'

	printf '\n\n\n--- /etc/pacman.d/mirrorlist (active entries) ---\n\n'
	grep -vE '^\s*#|^\s*$' /etc/pacman.d/mirrorlist 2>/dev/null ||
		printf 'could not read.\n'

	printf '\n\n\n--- /etc/mkinitcpio.conf (comments removed) ---\n\n'
	grep -vE '^\s*#|^\s*$' /etc/mkinitcpio.conf 2>/dev/null ||
		printf 'could not read.\n'

	printf '\n\n\n--- /etc/locale.conf ---\n\n'
	cat /etc/locale.conf 2>/dev/null || printf 'could not read.\n'

	printf '\n\n\n--- /etc/locale.gen (enabled locales) ---\n\n'
	grep -vE '^\s*#|^\s*$' /etc/locale.gen 2>/dev/null || printf 'could not read.\n'

	printf '\n\n\n--- /etc/environment (sensitive entries redacted) ---\n\n'
	grep -vE '(TOKEN|KEY|PASS|SECRET|API_|PASSWORD)' /etc/environment 2>/dev/null || printf 'could not read.\n'

	printf '\n\n\n--- /etc/vconsole.conf ---\n\n'
	cat /etc/vconsole.conf 2>/dev/null || printf 'could not read.\n'

	printf '\n\n\n--- /etc/hostname and /etc/hosts ---\n\n'
	cat /etc/hostname 2>/dev/null
	printf -- '\n\n\n'
	grep -vE '^\s*#|^\s*$' /etc/hosts 2>/dev/null

	printf '\n\n\n--- Bootloader Kernel Line ---\n\n'
	# GRUB and systemd-boot keep it in different places; both are checked.
	if [ -r /etc/default/grub ]; then
		grep -E '^GRUB_CMDLINE' /etc/default/grub 2>/dev/null
	elif [ -r /etc/kernel/cmdline ]; then
		cat /etc/kernel/cmdline
	else
		printf 'neither /etc/default/grub nor /etc/kernel/cmdline found.\n'
	fi
	printf 'grub layout: '
	if [ -d /boot/grub ]; then printf 'EFI system (/boot/grub)\n'; else printf 'no /boot/grub\n'; fi

	printf '\n\n\n--- /etc/modprobe.d/ ---\n\n'
	local f
	for f in /etc/modprobe.d/*.conf; do
		[ -e "$f" ] || continue
		printf '\n\n\n>> %s:\n' "$f"
		cat "$f" 2>/dev/null
	done

	printf '\n\n\n--- /etc/udev/rules.d/ (relevant rules) ---\n\n'
	for f in /etc/udev/rules.d/*nvidia* /etc/udev/rules.d/*pm* \
		/etc/udev/rules.d/*power* /etc/udev/rules.d/*gpu*; do
		[ -e "$f" ] || continue
		printf '\n\n\n>> %s:\n' "$f"
		cat "$f" 2>/dev/null
	done

	printf '\n\n\n--- Custom systemd Units (/etc/systemd/system) ---\n\n'
	for f in /etc/systemd/system/*.service /etc/systemd/system/*.timer; do
		[ -e "$f" ] || continue
		printf '\n\n\n>> %s:\n' "$f"
		# Only the definition blocks are printed. What a unit does is
		# stated in [Service] ExecStart, and dumping whole unit files
		# would inflate the report for little gain.
		sed -n '/^\[/,/^$/p' "$f" 2>/dev/null | head -n 30
	done

	printf '\n\n\n--- EFI Boot Entries (efibootmgr) ---\n\n'
	if ! command -v efibootmgr >/dev/null 2>&1; then
		printf 'efibootmgr not found (package: efibootmgr).\n'
	elif sudo_ready; then
		sudo -n efibootmgr -v 2>/dev/null || printf 'efibootmgr could not run.\n'
	else
		note_skipped_privileged 'efibootmgr (EFI boot entries)'
	fi
}
