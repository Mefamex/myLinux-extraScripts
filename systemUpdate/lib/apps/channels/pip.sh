#!/usr/bin/env bash
# pip channel — Python --user packages

CHANNEL_ID="pip"
CHANNEL_LABEL="Python --user packages"
CHANNEL_PRESENT="command -v pip"
CHANNEL_REPORT="@_ch_pip_report"
CHANNEL_UPDATE="@_ch_upd_pip"

# The list of outdated pip --user packages.
_ch_pip_report() {
	pip list --user --outdated --format=columns 2>/dev/null
}

# `pip install --user -U` alone is useless: you have to extract the outdated
# package names from the list first and pass those.
_ch_upd_pip() {
	local pkgs
	pkgs=$(pip list --user --outdated --format=freeze 2>/dev/null |
		sed -n 's/^\([-._[:alnum:]]*\)==.*/\1/p')
	if [ -z "$pkgs" ]; then
		info "nothing to update"
		return 0
	fi
	info "$(printf '%s' "$pkgs" | tr '\n' ' ')"

	# --break-system-packages is required here, not optional. Arch ships
	# /usr/lib/python3.x/EXTERNALLY-MANAGED (PEP 668) and pip refuses to
	# install at all without it — MEASURED, it exits with
	# "error: externally-managed-environment". The flag only lifts that
	# refusal; combined with --user it writes exclusively under ~/.local and
	# never touches the system site-packages. Anything more correct for
	# individual tools is pipx or uv, which are separate channels here; this
	# channel exists for the leftovers that were installed with plain pip
	# (git-filter-repo, for example).
	# shellcheck disable=SC2086  # pkgs is a list of names; splitting is intended
	pip install --user --break-system-packages -U $pkgs
}
