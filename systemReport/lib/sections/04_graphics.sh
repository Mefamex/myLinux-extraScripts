#!/usr/bin/env bash
#
# lib/sections/04_graphics.sh — sourced file, DO NOT RUN DIRECTLY
#
# systemReport — 04_graphics
#
# GPU driver, connected displays, DRM/KMS connector state, OpenGL renderer.
#
# Display enumeration is compositor specific: Wayland tools (wlr-randr,
# hyprctl, swaymsg) and the X11 tool (xrandr) are all tried independently and
# every one that exists is run. Version 3.1 chained these with `&&`, so the
# first available tool stopped the chain and the rest were never reached.
#
# Depends on: nothing

section_04() {
	printf -- '\n\n\n--- GPU Drivers ---\n\n'
	lspci -k 2>/dev/null | grep -A 2 -E '(VGA|3D|Display)' || echo 'lspci could not run.'

	printf '\n\n\n--- NVIDIA Status ---\n\n'
	if command -v nvidia-smi >/dev/null 2>&1; then
		nvidia-smi 2>/dev/null || printf 'nvidia-smi could not run.\n'
	else
		printf 'no NVIDIA driver active.\n'
	fi

	printf '\n\n\n--- Display Outputs ---\n\n'
	local found=0
	if command -v hyprctl >/dev/null 2>&1; then
		printf '\n\n\n[hyprctl monitors]\n'
		hyprctl monitors 2>/dev/null
		found=1
	fi
	if command -v wlr-randr >/dev/null 2>&1; then
		printf '\n\n\n[wlr-randr]\n'
		wlr-randr 2>/dev/null
		found=1
	fi
	if command -v swaymsg >/dev/null 2>&1; then
		printf '\n\n\n[swaymsg -t get_outputs]\n'
		swaymsg -t get_outputs 2>/dev/null
		found=1
	fi
	if command -v kscreen-doctor >/dev/null 2>&1; then
		printf '\n\n\n[kscreen-doctor -o]\n'
		kscreen-doctor -o 2>/dev/null
		found=1
	fi
	if command -v xrandr >/dev/null 2>&1; then
		printf '\n\n\n[xrandr --listmonitors]\n'
		xrandr --listmonitors 2>/dev/null
		found=1
	fi
	[ "$found" -eq 1 ] || printf 'no known display tool found.\n'

	printf '\n\n\n--- DRM/KMS Connector Status ---\n\n'
	if [ -d /sys/class/drm ]; then
		# The card*-* glob covers both the connector directories
		# (card0-DP-1) and the card directory itself (card0). Entries
		# without a status file are filtered out.
		local status_file dir name state
		for status_file in /sys/class/drm/card*-*/status; do
			[ -e "$status_file" ] || continue
			dir="$(dirname "$status_file")"
			name="$(basename "$dir")"
			state="$(cat "$status_file" 2>/dev/null || echo unknown)"
			printf '%s: %s\n' "$name" "$state"
			# The modes file exists even when nothing is plugged in, but
			# it only lists resolutions the display currently supports
			# while it is connected.
			if [ "$state" = connected ] && [ -r "$dir/modes" ]; then
				printf '  modes (first 10):\n'
				sed -n '1,10p' "$dir/modes" | sed 's/^/    /'
			fi
		done
	else
		printf '/sys/class/drm not found.\n'
	fi

	printf '\n\n\n--- OpenGL ---\n\n'
	if command -v glxinfo >/dev/null 2>&1; then
		glxinfo -B 2>/dev/null || printf 'glxinfo could not run.\n'
	elif command -v eglinfo >/dev/null 2>&1; then
		# In a Wayland session there is no X11, so EGL is the more
		# accurate answer.
		eglinfo -B 2>/dev/null | head -n 20 || printf 'eglinfo could not run.\n'
	else
		printf 'neither glxinfo (mesa-utils) nor eglinfo found.\n'
	fi
}
