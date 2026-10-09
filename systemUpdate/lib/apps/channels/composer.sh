#!/usr/bin/env bash
# composer channel — Composer global packages

CHANNEL_ID="composer"
CHANNEL_LABEL="Composer global packages"
CHANNEL_PRESENT="@_ch_composer_available"
CHANNEL_REPORT="composer global show -N"
CHANNEL_UPDATE="composer global update"

# composer exists AND has a global composer.json (created by `composer global
# require ...`). Without it `composer global show -N` fails loudly (rc=1,
# "could not find composer.json") instead of listing nothing, which polluted
# the report and claimed a failed command.
# Home resolution mirrors Composer\Config::getHomeDir():
# COMPOSER_HOME env -> ~/.composer (legacy) -> $XDG_CONFIG_HOME|~/.config/composer
_ch_composer_available() {
	command -v composer >/dev/null 2>&1 || return 1
	local home
	if [ -n "${COMPOSER_HOME:-}" ]; then
		home="$COMPOSER_HOME"
	elif [ -d "$HOME/.composer" ]; then
		home="$HOME/.composer"
	else
		home="${XDG_CONFIG_HOME:-$HOME/.config}/composer"
	fi
	[ -f "$home/composer.json" ]
}
