#!/usr/bin/env bash
#
# lib/sections/03_storage.sh — sourced file, DO NOT RUN DIRECTLY
#
# systemReport — 03_storage
#
# Disk layout, usage, inodes, partition table, SMART health. fdisk and smartctl
# need root.
#
# Depends on: sudo_ready, note_skipped_privileged (lib/sudo.sh)

section_03() {
	printf -- '\n\n\n--- Block Devices (lsblk) ---\n\n'
	lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT,UUID,MODEL 2>/dev/null ||
		echo 'lsblk could not run.'

	printf '\n\n\n--- Mounted Filesystems (findmnt --real) ---\n\n'
	findmnt --real 2>/dev/null || echo 'could not read'

	printf '\n\n\n--- Disk Usage (df) ---\n\n'
	df -hT --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null

	printf '\n\n\n--- Inode Usage (df -i) ---\n\n'
	df -iT --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null

	printf '\n\n\n--- Partition Table (fdisk) ---\n\n'
	if ! command -v fdisk >/dev/null 2>&1; then
		printf 'fdisk not found (package: fdisk / util-linux).\n'
	elif sudo_ready; then
		sudo -n fdisk -l 2>/dev/null || printf 'fdisk could not run.\n'
	else
		note_skipped_privileged 'fdisk (partition table)'
	fi

	printf '\n\n\n--- SMART Health ---\n\n'
	if ! command -v smartctl >/dev/null 2>&1; then
		printf 'smartmontools not installed (package: smartmontools).\n'
	else
		# Real disks come from lsblk. Globbing /dev/sd* would miss NVMe,
		# mmcblk and virtio devices.
		local drive
		while IFS= read -r drive; do
			[ -n "$drive" ] || continue
			[ -b "$drive" ] || continue
			printf '\n\n\n>> %s:\n' "$drive"
			if sudo_ready; then
				# -H asks for the overall health verdict only. The
				# full SMART data (percentage used, media errors) would
				# inflate the report considerably. smartctl's exit code
				# is checked before the filter, so a disk that simply
				# has no health line is not reported as unreadable.
				if _smart="$(sudo -n smartctl -H "$drive" 2>/dev/null)"; then
					printf '%s\n' "$_smart" |
						grep -iE 'result|overall-health' ||
						printf 'no SMART health line for %s.\n' "$drive"
				else
					printf 'SMART data could not be read for %s.\n' "$drive"
				fi
				unset _smart
			else
				note_skipped_privileged "SMART ($drive)"
			fi
		done < <(lsblk -dno PATH 2>/dev/null)
	fi
}
