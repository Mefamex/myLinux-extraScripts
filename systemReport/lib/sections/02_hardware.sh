#!/usr/bin/env bash
#
# lib/sections/02_hardware.sh — sourced file, DO NOT RUN DIRECTLY
#
# systemReport — 02_hardware
#
# CPU, RAM, PCI/USB devices, temperatures, battery. RAM slot details need root
# because dmidecode reads from SMBIOS and requires access to /dev/mem.
#
# Depends on: sudo_ready, note_skipped_privileged (lib/sudo.sh)

section_02() {
	printf -- '\n\n\n--- CPU (lscpu) ---\n\n'
	lscpu 2>/dev/null || echo 'lscpu not found.'

	printf '\n\n\n--- RAM (free) ---\n\n'
	free -h 2>/dev/null || echo 'could not read'

	printf '\n\n\n--- Swap ---\n\n'
	swapon --show 2>/dev/null || echo 'no active swap.'

	printf '\n\n\n--- RAM Slot Details (dmidecode) ---\n\n'
	if ! command -v dmidecode >/dev/null 2>&1; then
		printf 'dmidecode not installed (package: dmidecode).\n'
	elif sudo_ready; then
		sudo -n dmidecode -t memory 2>/dev/null |
			grep -E 'Size:|Type:|Speed:|Manufacturer:|Locator:|Part Number:' ||
			printf 'dmidecode could not run.\n'
	else
		note_skipped_privileged 'dmidecode (RAM slot details)'
	fi

	printf '\n\n\n--- PCI Devices (lspci -nnk) ---\n\n'
	lspci -nnk 2>/dev/null || echo 'lspci not found (package: pciutils).'

	printf '\n\n\n--- USB Devices (lsusb) ---\n\n'
	lsusb 2>/dev/null || echo 'lsusb not found (package: usbutils).'

	printf '\n\n\n--- Temperature Sensors ---\n\n'
	if command -v sensors >/dev/null 2>&1; then
		sensors 2>/dev/null
	else
		printf 'lm_sensors not installed (package: lm_sensors).\n'
	fi

	printf '\n\n\n--- Battery ---\n\n'
	if command -v upower >/dev/null 2>&1; then
		local bat
		bat="$(upower -e 2>/dev/null | grep battery || true)"
		if [ -n "$bat" ]; then
			local b
			# A here-string keeps the loop out of a subshell, so the
			# output is not lost and no variable assignment is needed.
			while IFS= read -r b; do
				[ -n "$b" ] || continue
				printf '\n\n\n>> %s:\n' "$b"
				upower -i "$b" 2>/dev/null
			done <<<"$bat"
		else
			printf 'no battery found (not a laptop, or no battery).\n'
		fi
	else
		printf 'upower not installed (package: upower).\n'
	fi

	printf '\n\n\n--- Block Device Summary ---\n\n'
	if command -v lsblk >/dev/null 2>&1; then
		lsblk -d -o NAME,SIZE,ROTA,TRAN,MODEL 2>/dev/null
	else
		printf 'lsblk not found.\n'
	fi
}
