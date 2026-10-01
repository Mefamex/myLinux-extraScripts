#!/usr/bin/env bash
#
# lib/sudo.sh — sourced file, DO NOT RUN DIRECTLY
#
# This file is `source`d by systemReport.sh. Running it on its own does
# nothing and dies on the variables it expects. The shebang is only there so the
# linter recognises the file as shell.
#
# systemReport — sudo.sh
#
# Root privileges are validated exactly once. `sudo -v` prompts for the
# password and refreshes the sudoers timestamp, which stays valid for the rest
# of the session, so every later `sudo` call in the run goes through without
# asking again. The user types their password once; the script invokes sudo
# dozens of times.
#
# If validation fails the script does NOT abort. The five privileged checks are
# skipped and the reason is recorded in the report, because a partial report is
# more useful than no report.
#
# Depends on: $USE_SUDO_CHECKS, sets $SUDO_OK

prepare_sudo() {
	SUDO_OK=0

	# Already root: nothing to validate.
	if [ "$(id -u)" -eq 0 ]; then
		SUDO_OK=1
		ok "Running as root, all checks will run."
		return 0
	fi

	if [ "$USE_SUDO_CHECKS" != 1 ]; then
		warn "Skipping checks that need root (config: USE_SUDO_CHECKS=0)."
		return 0
	fi

	info "Some checks need root (your password is asked for once)..."

	# -v validates and refreshes the timestamp. -n would be wrong here: the
	# password has not been entered yet.
	if sudo -v; then
		SUDO_OK=1
	else
		warn "sudo validation failed, skipping checks that need root:"
		warn "  dmidecode (RAM slots), fdisk (partition table),"
		warn "  smartctl (disk health), dmesg (kernel log), efibootmgr (EFI)."
		return 0
	fi
	return 0
}

# Single place expressing "does this part need root". Section files call this
# instead of writing "sudo", which keeps them short and makes every skipped
# check produce the same sentence.
sudo_ready() {
	[ "$SUDO_OK" -eq 1 ]
}

# Written into the report so the reader knows a check is absent, not just empty.
note_skipped_privileged() {
	printf 'skipped (needs root): %s\n' "$*"
}

# Fix report ownership. When the script is launched via `sudo -u`, $HOME is
# /root; without this the report would be written into root's home. The real
# user's home is looked up and the report stays with them.
#
# If the report folder is already owned by the calling user, nothing is done.
fix_report_ownership() {
	[ -n "${SUDO_USER:-}" ] || return 0

	# The group is not guaranteed to share the user's name. Version 3.1 used
	# "$SUDO_USER":"$SUDO_USER" and failed silently whenever it differed.
	local user="$SUDO_USER" group home
	group="$(id -gn "$user" 2>/dev/null)" || group="$user"
	home="$(getent passwd "$user" 2>/dev/null | cut -d: -f6)"

	if [ -n "$home" ] && [ -d "$home" ] && [ "$REPORT_ROOT" = "$home/systemReport" ]; then
		# Root is already inside the user's home, so only ownership needs
		# fixing; the path itself is fine.
		chown -R "$user":"$group" "$REPORT_DIR" 2>/dev/null &&
			ok "Report folder ownership given to $user."
	elif [ -n "$home" ] && [ -d "$home" ]; then
		warn "Report root is not under $home, ownership left unchanged."
	fi
}
