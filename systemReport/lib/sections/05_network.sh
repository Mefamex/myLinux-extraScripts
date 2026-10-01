#!/usr/bin/env bash
#
# lib/sections/05_network.sh — sourced file, DO NOT RUN DIRECTLY
#
# systemReport — 05_network
#
# IP addresses, routes, DNS, listening ports, NetworkManager state.
#
# WARNING: this is the most sensitive section in the report. It contains real IP
# addresses, MAC addresses and your local network topology. Review it before
# sharing (see 00_privacy).
#
# Depends on: nothing

section_05() {
	printf -- '\n\n\n--- Interfaces (ip a) ---\n\n'
	ip -c=never a 2>/dev/null || echo 'ip could not run.'

	printf '\n\n\n--- Routing Table ---\n\n'
	ip route 2>/dev/null || echo 'could not read'
	ip -6 route 2>/dev/null

	printf '\n\n\n--- DNS (resolv.conf) ---\n\n'
	cat /etc/resolv.conf 2>/dev/null || echo 'could not read.'

	printf '\n\n\n--- Listening Ports (ss) ---\n\n'
	ss -tulpen 2>/dev/null || echo 'ss not found (package: iproute2).'

	printf '\n\n\n--- NetworkManager ---\n\n'
	if command -v nmcli >/dev/null 2>&1; then
		nmcli device status 2>/dev/null
		printf '\n\n\n--- Active Connections ---\n\n'
		nmcli connection show --active 2>/dev/null
	else
		printf 'NetworkManager not installed.\n'
	fi

	printf '\n\n\n--- Other Network Managers ---\n\n'
	systemctl is-active systemd-networkd 2>/dev/null | sed 's/^/systemd-networkd: /'
	systemctl is-active iwd 2>/dev/null | sed 's/^/iwd            : /'
}
