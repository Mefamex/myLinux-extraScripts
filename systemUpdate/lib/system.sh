#!/usr/bin/env bash
#
# lib/system.sh — source file, NOT meant to be run directly
#
# systemUpdate — system.sh
#
# ACTION CODE. Everything here CHANGES the system. Reporting lives in
# lib/status.sh; the two are deliberately separate.
#
# System update order: keyring → system+AUR → firmware → DKMS → .pacnew.
#
# ORDER MATTERS. Firmware goes near the end because it can also bump the
# kernel; DKMS modules (nvidia, tuxedo) then get built against the new kernel.
# Doing firmware first would build against a kernel that is not the one you are
# about to boot, which risks a black screen on next boot.
#
# Deliberately NOT done here:
#   - `pacman -Syyu`: -yy means refresh-twice, which is unnecessary (the sync DB
#     is at most 24h old) and forcing it can only cause trouble.
#   - `--noconfirm`: the user asked for confirmations, so package
#     installation still asks every time.
#   - `pacman -R`/`-Rns`: removing packages is the user's decision.
#
# Depends on: section/warn/info/confirm (lib/log.sh)

system_update() {
	local kernel_before kernel_after reboot=0 firmware_done=0 dkms_output pacnew

	# Whether a reboot is needed cannot be guessed reliably from the file
	# system: the old /usr/lib/modules directory is deleted after an upgrade,
	# uname -r does not change until you reboot, and `fwupdmgr
	# check-reboot-needed` asks a question and hangs inside a script.
	# Instead we record the kernel state BEFORE the update and COMPARE it
	# afterwards, so a warning appears only if a kernel was really installed.
	kernel_before=$(_kernel_packages)
	if [ -z "$kernel_before" ]; then
		info "no kernel package visible to pacman — reboot detection unavailable"
	fi

	section "[1/5] Updating archlinux-keyring..."

	# --needed is required: without it pacman reinstalls packages that are
	# already up to date ("--needed  Do not reinstall the targets that are
	# already up-to-date"). Partial-upgrade risk is nil: archlinux-keyring's
	# only dependency is pacman, and pacman is in HoldPkg.
	if ! sudo pacman -Sy --needed archlinux-keyring; then
		warn "Keyring update failed, stopping."
		return 1
	fi

	section "[2/5] Updating system and AUR packages..."

	# yay handles official repos and AUR in a single pass; a separate
	# `pacman -Syu` would only download the sync DB a second time for nothing.
	# --answerclean/--answerdiff only silence PKGBUILD questions, they do NOT
	# suppress the install confirmation. (yay --clean means "remove
	# dependencies", not "suppress the menu" — measured on yay 13.0.1.)
	# --noprogressbar: the pacman man page calls this flag useful for
	# "scripts that capture output". Because we log, the progress bar rewrote
	# itself with \r on a single line and made the log unreadable.
	if ! yay -Syu --answerclean None --answerdiff None --noprogressbar; then
		warn "Update failed, stopping."
		return 1
	fi

	section "[3/5] Checking firmware..."
	if _firmware_step; then
		firmware_done=1
	fi

	section "[4/5] DKMS modules (kernel drivers)..."
	# These are what a kernel upgrade breaks. Any line NOT containing
	# "installed" means the module did not build; see the notes in this file
	# about whether that filter should be more specific.
	if ! command -v dkms >/dev/null 2>&1; then
		info "dkms is not installed"
	else
		dkms_output=$(dkms status 2>/dev/null)
		printf '%s\n' "$dkms_output" | sed 's/^/    /'
		# pipefail together with `grep -q` produces SIGPIPE on early exit, so
		# the output is captured into a variable and searched there.
		if [ -n "$dkms_output" ] && printf '%s\n' "$dkms_output" | grep -qv installed; then
			printf '\n'
			warn "there are unbuilt DKMS modules (the 'added' lines above)."
			info "to rebuild them:  sudo dkms autoinstall"
		fi
	fi

	section "[5/5] Pending configuration (.pacnew) files..."
	# A .pacnew file means the package was updated but your /etc setting was
	# kept. It is never deleted and never inspected automatically: until you
	# look at it, the package's new defaults are simply not applied.
	#
	# /usr/bin/find is spelled out. Aliases do not expand when a script is
	# executed (they only expand at parse time in an interactive shell), but
	# if this file were sourced into a shell an `alias find=fd` would be
	# baked into the body and fd knows neither -name nor -o, so the command
	# would silently return nothing. The absolute path cuts both cases.
	pacnew=$(/usr/bin/find /etc \( -name '*.pacnew' -o -name '*.pacsave' \) 2>/dev/null)
	if [ -n "$pacnew" ]; then
		printf '%s\n' "$pacnew" | sed 's/^/    /'
		info "to review them:  sudo pacdiff"
	else
		info "none pending"
	fi

	# --- reboot decision -------------------------------------------------
	kernel_after=$(_kernel_packages)
	if [ -z "$kernel_before" ] || [ -z "$kernel_after" ]; then
		# With an empty baseline the comparison is impossible; saying "no
		# reboot needed" would be WRONG.
		reboot=1
		warn "could not determine the reboot status (no kernel package visible)."
		info "check it yourself:  pacman -Qo /usr/lib/modules"
	elif [ "$kernel_after" != "$kernel_before" ]; then
		reboot=1
		info "the kernel was updated; reboot before continuing"
		info "systemctl reboot  (or: reboot)"
	fi

	# A flashed firmware also needs a reboot: flashing only completes on the
	# next boot.
	if [ "$firmware_done" = 1 ]; then
		reboot=1
		info "firmware was flashed, a reboot is required"
	fi

	printf '================================\n'
	if [ "$reboot" -eq 0 ]; then
		printf '==> No reboot required.\n\n\n'
	else
		printf '==> A reboot IS required.\n\n\n'
	fi
	return 0
}

# Packages that really are a KERNEL, as "name version".
#
# This was wrong three times; each fix was driven by a measurement:
#
#  1) `grep -E '^linux'` also matched linux-wifi-hotspot, linux-headers,
#     linux-api-headers and 14 linux-firmware-* packages on this machine, so
#     updating any of them claimed "a reboot is required" even though the
#     kernel had not changed. MEASURED: 4 false matches.
#
#  2) `grep -vE '^linux-(headers|firmware)'` still let linux-wifi-hotspot
#     through.
#
#  3) `pacman -Qo /usr/lib/modules | awk '{print $1,$2}'` gets the ownership
#     right but FIELD POSITIONS ARE LANGUAGE DEPENDENT. On this machine
#     (LANG=tr_TR.UTF-8) it prints "paketine ait" instead of "is owned by":
#         /usr/lib/modules/, linux 7.2.7.arch1-1 paketine ait.
#     So the English assumption `$1 $2` was wrong; it is `$2 $3`. Code that
#     worked in an English locale returned nothing silently in Turkish.
#
# The fix combines two approaches:
#   - Candidates come from `pacman -Qqo /usr/lib/modules`, which prints package
#     NAMES ONLY (Qqo = quiet + only). No prose, therefore no locale
#     dependency. The query runs ONCE — inside a loop it would rescan the
#     whole database once per candidate.
#   - A candidate is a kernel only if it installs files under
#     /usr/lib/modules/<version>/kernel/. Why kernel/ and not build/: the
#     linux-headers package also installs into /usr/lib/modules but ONLY
#     build/ and source/ (MEASURED: 21868 files, all headers; the kernel/ filter
#     matched 0). Real kernel modules live under kernel/ (MEASURED: 7740
#     matches). The distinction is exact.
#   - The version comes from `pacman -Q`, which also prints no prose.
_kernel_packages() {
	local candidates pkg version
	candidates=$(pacman -Qqo /usr/lib/modules 2>/dev/null)
	[ -n "$candidates" ] || return 0

	for pkg in $candidates; do
		pacman -Ql "$pkg" 2>/dev/null | awk '{print $2}' |
			grep -q "^/usr/lib/modules/[^/]*/kernel/" || continue
		version=$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')
		printf '%s %s\n' "$pkg" "$version"
	done
	return 0
}

# _firmware_step  →  0: firmware FLASHED, 1: nothing to do / failed
#
# The return value carries "was it flashed?" so system_update can make the
# reboot decision.
#
# sudo is NOT used. fwupd obtains privileges through polkit by itself; that was
# measured working on this machine. (The Arch fwupd 2.1.8 man page says nothing
# about root/sudo/polkit, so this is not a rule we are bending — it is simply
# what works.)
_firmware_step() {
	local refresh_rc output rc

	if ! command -v fwupdmgr >/dev/null 2>&1; then
		info "fwupd is not installed"
		return 1
	fi

	fwupdmgr refresh >/dev/null 2>&1
	refresh_rc=$?
	# rc=0 refreshed, rc=2 already current. BOTH are not errors. We used to
	# treat rc=2 as a failure and print "metadata could not be refreshed".
	if [ "$refresh_rc" -gt 0 ] && [ "$refresh_rc" -ne 2 ]; then
		info "firmware metadata could not be refreshed, skipping"
	fi

	output=$(fwupdmgr get-updates 2>&1)
	rc=$?
	# rc=2 = NOTHING_TO_DO. CAREFUL: even when there is no update fwupd prints
	# a list of "devices without updates" (23 lines on this machine), so
	# checking whether the output is empty is NOT ENOUGH on its own. The
	# decision is based on rc.
	if [ "$rc" -eq 0 ] && [ -n "${output//[[:space:]]/}" ]; then
		printf '%s\n' "$output"
		if confirm "A firmware update was found. Apply it?"; then
			if fwupdmgr update; then
				return 0
			fi
			warn "Firmware update failed."
			return 1
		fi
		info "Firmware update skipped."
		return 1
	fi
	if [ "$rc" -eq 2 ] || [ -z "${output//[[:space:]]/}" ]; then
		info "Firmware is current (no update available)."
		return 1
	fi
	# A real error (rc=1): print fwupd's own message verbatim.
	printf '%s\n' "$output"
	return 1
}
