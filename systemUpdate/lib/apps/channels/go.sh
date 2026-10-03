#!/usr/bin/env bash
# go channel — Go-installed tools

CHANNEL_ID="go"
CHANNEL_LABEL="Go-installed tools"
CHANNEL_PRESENT="@_ch_go_available"
CHANNEL_REPORT="@_ch_go_report"
CHANNEL_UPDATE="@_ch_upd_go"

# If `go` is NOT installed the channel must count as absent. Otherwise _go_report
# and _upd_go call `go version -m` on nothing, return empty silently, and the
# user concludes their tools are current.
_ch_go_available() {
	command -v go >/dev/null 2>&1 || return 1
	[ -d "$GO_BIN_DIR" ] && [ -n "$(/usr/bin/find "$GO_BIN_DIR" -maxdepth 1 -type f 2>/dev/null)" ]
}

_ch_go_report() {
	local b
	for b in "$GO_BIN_DIR"/*; do
		[ -x "$b" ] && [ -f "$b" ] || continue
		printf '%-14s %s\n' "$(basename "$b")" "$(_ch_go_module "$b")"
	done
}

# The module information EMBEDDED in the binary. We do NOT guess: the origin is
# read exactly from here, so installing from the wrong repository is impossible.
_ch_go_module() {
	go version -m "$1" 2>/dev/null |
		awk '$1=="mod"{print $2" "$3; exit}'
}

# There is NO bulk update command for Go tools; `go install <main pkg>@latest`
# has to run once per tool.
_ch_upd_go() {
	local b name path skipped=0
	for b in "$GO_BIN_DIR"/*; do
		[ -x "$b" ] && [ -f "$b" ] || continue
		name=$(basename "$b")
		path=$(go version -m "$b" 2>/dev/null | awk '$1=="path"{print $2; exit}')
		if [ -z "$path" ]; then
			printf '    skipped: %s (no embedded module information)\n' "$name"
			skipped=$((skipped + 1))
			continue
		fi
		# A path with no domain (e.g. "log-viewer") is not a public
		# repository, so @latest cannot resolve it — it is one of your own
		# local projects.
		case "$path" in
		*.*/*) ;;
		*)
			printf '    skipped: %s (not a public repository: %s)\n' "$name" "$path"
			skipped=$((skipped + 1))
			continue
			;;
		esac
		printf '    -> %s@latest\n' "$path"
		if go install "$path@latest"; then
			printf '      updated\n'
		else
			warn "$path could not be updated"
		fi
	done
	[ "$skipped" -gt 0 ] && info "$skipped tool(s) skipped"
	return 0
}
