#!/usr/bin/env bash
#
# lib/config.sh — source file, NOT meant to be run directly
#
# Sourced by systemUpdate.sh; run on its own it does nothing useful and dies on
# an undefined variable. The shebang exists only for shellcheck.
#
# systemUpdate — config.sh
#
# Settings loader. No personal value is hardcoded anywhere in the script: each
# one comes either from the `config` file or from the environment. The
# environment variable OVERRIDES the file:
#   SYSUPDATE_LOG_DIR=/tmp/log ./systemUpdate.sh
#
# Search order:
#   <script dir>/config              default
#   SYSUPDATE_CONFIG=/full/path      point somewhere else
#
# Depends on: $_HERE (computed by systemUpdate.sh)

config_load() {
	# `config` is TRACKED in git (not ignored) and every setting in it is
	# commented out, so a fresh clone is immediately runnable and the shipped
	# defaults are visible to a reviewer. There is no template file: there is
	# nothing to copy, because there is no per-user value to hide. If you want
	# to pin a value, uncomment the line here and commit it, or keep it local
	# and pass it through the environment instead.
	#
	# A missing config is therefore fine and silently skipped — every setting
	# below has a built-in default.
	local cfg=""
	if [ -n "${SYSUPDATE_CONFIG:-}" ]; then
		cfg="$SYSUPDATE_CONFIG"
	elif [ -r "$_HERE/config" ]; then
		cfg="$_HERE/config"
	fi
	if [ -n "$cfg" ]; then
		# shellcheck source=/dev/null
		. "$cfg"
	fi

	# --- defaults --------------------------------------------------------
	#
	# All machine-independent; they only rely on $HOME and XDG variables.
	# Channel names are NOT here but in lib/apps.sh, because they describe what
	# the script does rather than a personal preference.
	#
	# Precedence is uniform: environment > config file > default.
	# to find where a setting is used:  grep -rn LOG_DIR lib/
	#
	# LOG_DIR is intentionally left empty here. When empty, log_open() resolves
	# it via a cascade (see lib/log.sh resolve_log_dir()):
	#   1. xdg-user-dir DOCUMENTS       -> localized "Documents" (e.g. Belgeler)
	#   2. English names                -> $HOME/Documents, $HOME/Document
	#   3. Home backup (not hidden)     -> $HOME/systemUpdate
	#   4. XDG state dir (last resort)  -> ${XDG_STATE_HOME:-$HOME/.local/state}/systemUpdate
	#
	# Only SYSUPDATE_* env vars are read; bare LOG_DIR/LOG_KEEP/etc. from the
	# user's shell are ignored to avoid accidental overrides.
	# A value already set by the config file (sourced above) is KEPT: the
	# built-in default only applies when neither the config file nor the
	# environment provided one. Precedence: environment > config file > default.
	# shellcheck disable=SC2034  # LOG_DIR is read in lib/log.sh
	LOG_DIR="${SYSUPDATE_LOG_DIR:-${LOG_DIR:-}}"
	# shellcheck disable=SC2034  # SKIP_CHANNELS is read in lib/apps.sh
	SKIP_CHANNELS="${SYSUPDATE_SKIP_CHANNELS:-${SKIP_CHANNELS:-}}"
	# shellcheck disable=SC2034  # GO_BIN_DIR is read in lib/apps.sh
	# GO_BIN_DIR: default from go env, so a custom GOBIN or GOPATH is respected.
	# `go env GOBIN` prints an EMPTY line with rc=0 when GOBIN is unset, so the
	# empty case must fall back too — the old one-liner's `||` default never
	# fired, leaving GO_BIN_DIR="" and the go channel silently "not installed".
	GO_BIN_DIR="${SYSUPDATE_GO_BIN_DIR:-${GO_BIN_DIR:-}}"
	if [ -z "$GO_BIN_DIR" ]; then
		_go_bin="$(go env GOBIN 2>/dev/null)"
		_go_path="$(go env GOPATH 2>/dev/null)"
		if [ -n "$_go_bin" ]; then
			GO_BIN_DIR="$_go_bin"
		elif [ -n "$_go_path" ]; then
			GO_BIN_DIR="$_go_path/bin"
		else
			# No go toolchain at all; assume the conventional layout.
			GO_BIN_DIR="$HOME/go/bin"
		fi
		unset _go_bin _go_path
	fi
	# shellcheck disable=SC2034  # LOG_KEEP is read in lib/log.sh
	LOG_KEEP="${SYSUPDATE_LOG_KEEP:-${LOG_KEEP:-50}}"
	# shellcheck disable=SC2034  # STATUS_AUR is read in lib/status.sh
	STATUS_AUR="${SYSUPDATE_STATUS_AUR:-${STATUS_AUR:-0}}"
}
