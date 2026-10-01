#!/usr/bin/env bash
#
# lib/apps.sh — source file, NOT meant to be run directly
#
# systemUpdate — apps.sh
#
# Updates the payloads that pacman does NOT know about, because the tools
# themselves installed them.
#
# The important split: `go`, `nodejs`, `npm`, `rust`, `python-pipx`, `uv`,
# `docker`, `code`, `dotnet-sdk`, `jdk-openjdk` are all pacman packages and are
# already updated by the system step, so they are NOT repeated here. What is
# left is what those tools wrote into their own directories: npm global
# packages, VS Code extensions, pipx and uv applications, and binaries
# installed with `go install`.
#
# Channel table format:  "id|label|present|report|update"
#   id       short name; can be skipped via SKIP_CHANNELS in the config
#   label    the name shown on screen
#   present  command proving the channel is usable (if it fails, skip it)
#   report   command (or @function) printing "what would be updated"
#   update   command (or @function) run after confirmation
#            (empty = report only, nothing is ever updated)
#
# The "@" prefix means a function name. It makes the distinction explicit,
# since a bare command could also start with an underscore.
#
# Depends on: section/warn/info/report/confirm/_run (lib/log.sh),
#             $GO_BIN_DIR, $SKIP_CHANNELS (lib/config.sh)

# Marketplace constants for the VS Code channel. Not settings: they describe a
# public API, so there is nothing for a user to tune here.
_VSCODE_API='https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery?api-version=7.1-preview.1'
_VSCODE_BATCH=100
_VSCODE_TIMEOUT=25

_channels() {
	cat <<'CHANNELS'
npm|NPM global packages|command -v npm|npm outdated -g --depth=0|npm -g update
code|VS Code extensions|command -v code|@_code_report|code --update-extensions
pipx|pipx applications|command -v pipx|pipx list --short|pipx upgrade-all
uv|uv tools|command -v uv|uv tool list|uv tool upgrade --all
opencode|OpenCode|command -v opencode|opencode --version|opencode upgrade
claude|Claude Code|command -v claude|claude --version|claude update
codex|Codex CLI|command -v codex|codex --version|codex update
pnpm|pnpm|command -v pnpm|pnpm --version|pnpm self-update
pip|Python --user packages|command -v pip|@_pip_report|@_upd_pip
go|Go-installed tools|@_go_available|@_go_report|@_upd_go
cargo|Cargo crates|command -v cargo|cargo install --list|
docker|Docker images|docker info|docker images --format '{{.Repository}}:{{.Tag}}'|
flatpak|Flatpak apps|command -v flatpak|flatpak list --app --columns=application|
dotnet|.NET global tools|command -v dotnet|dotnet tool list --global|
composer|Composer global packages|command -v composer|composer global show -N|composer global update|
gh|GitHub CLI extensions|command -v gh|gh extension list|gh extension upgrade --all|
CHANNELS
}

# --- helpers used by the table --------------------------------------------

# VS Code extensions that have a NEWER version on the marketplace.
#
# Why this is not just `code --list-extensions --show-versions`: that command
# prints the INVENTORY — everything that is installed — so with 164 extensions
# it produced 164 lines, of which 137 said "already up to date". It answered
# "what do I have?" instead of the question the channel asks, "what would
# change?". That is also the ONLY channel that ever hit the old line cap, which
# is how the cap ended up hiding a wrong report rather than a long one.
#
# The `code` CLI has no "list outdated" flag, so the comparison is done against
# the marketplace API directly. MEASURED on this machine: all 164 extensions
# answered by 2 requests in ~3 s, and the real answer is 27 outdated — so the
# fixed report is 27 lines instead of 164, and every one of them is actionable.
#
# The API is public and unauthenticated. If it is unreachable, or curl/jq is not
# installed, this falls back to the old inventory with an explanation, so the
# channel never silently claims "nothing to update" when it did not check.
_code_report() {
	local installed ids total start payload resp latest line id cur want outdated=0

	installed=$(code --list-extensions --show-versions 2>/dev/null)
	[ -n "${installed//[[:space:]]/}" ] || return 0

	if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
		_code_report_fallback "$installed" "curl or jq is not installed"
		return 0
	fi

	ids=$(printf '%s\n' "$installed" | sed 's/@[^@]*$//')
	total=$(printf '%s\n' "$ids" | grep -c .)
	latest=""

	# One request per 100 extensions. MEASURED: the API accepts far more than
	# that in a single query, but batching keeps the payload small and the
	# worst case bounded if you have hundreds of extensions.
	#
	# The trailing newline has to be added by hand: `latest+=$(...)` strips it,
	# so without this the last line of one batch runs into the first line of
	# the next and produces a corrupt "version" (MEASURED: "1.4.0ms-vscode.cpptools").
	start=1
	while [ "$start" -le "$total" ]; do
		payload=$(printf '%s\n' "$ids" | sed -n "${start},$((start + _VSCODE_BATCH - 1))p" |
			jq -R . | jq -sc '{filters:[{criteria:map({filterType:7,value:.}),
			    pageNumber:1,pageSize:(length+10),sortBy:0,sortOrder:0}],flags:914}')
		[ -n "$payload" ] || break
		resp=$(curl -s -m "$_VSCODE_TIMEOUT" -X POST "$_VSCODE_API" \
			-H 'Content-Type: application/json' \
			-H 'Accept: application/json;api-version=7.1-preview.1' \
			-d "$payload" 2>/dev/null)
		latest+=$(
			printf '%s' "$resp" |
				jq -r '.results[0].extensions[]?
					| "\(.publisher.publisherName).\(.extensionName)\t\(.versions[0].version)"' \
					2>/dev/null
		)$'\n'
		start=$((start + _VSCODE_BATCH))
	done

	if [ -z "${latest//[[:space:]]/}" ]; then
		_code_report_fallback "$installed" "the marketplace API did not answer"
		return 0
	fi

	while IFS=@ read -r id cur; do
		[ -n "$id" ] || continue
		want=$(printf '%s\n' "$latest" | awk -F'\t' -v k="$id" '$1==k {print $2; exit}')
		[ -n "$want" ] || continue
		[ "$want" != "$cur" ] || continue
		printf '%-44s %s -> %s\n' "$id" "$cur" "$want"
		outdated=$((outdated + 1))
	done <<EOF
$installed
EOF

	[ "$outdated" -gt 0 ] && printf '%s of %s extensions have a newer version\n' \
		"$outdated" "$total"
	return 0
}

# Used when the marketplace cannot be reached. Reporting the inventory is not
# the same answer, so the reason is printed with it rather than leaving the user
# to read "164 extensions" as if all of them were updates.
_code_report_fallback() {
	local installed="$1" reason="$2"
	warn "cannot compare against the marketplace ($reason)"
	warn "listing what is installed instead — this is NOT the list of updates:"
	code --list-extensions --show-versions 2>/dev/null | sed 's/^/      /'
}

# The list of outdated pip --user packages.
_pip_report() {
	pip list --user --outdated --format=columns 2>/dev/null
}

# `pip install --user -U` alone is useless: you have to extract the outdated
# package names from the list first and pass those.
#
# sed instead of `cut -d= -f1`: cut passes through any line that does not
# contain "==" unchanged, so if pip's output ever changes shape (a version
# column shifts, a warning line gets mixed in) that line would be handed to
# `pip install` as a package name. sed only passes lines matching `name==ver`.
#
# The class is written as `[-._[:alnum:]]`: the `-` must come FIRST, otherwise
# the `._-` in the middle starts a RANGE and breaks the class. MEASURED:
# `[A-Za-z0-9._-]` matched nothing at all on this machine (GNU sed 4.10),
# while `[-._[:alnum:]]` works.
_upd_pip() {
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

# If `go` is NOT installed the channel must count as absent. Otherwise _go_report
# and _upd_go call `go version -m` on nothing, return empty silently, and the
# user concludes their tools are current.
_go_available() {
	command -v go >/dev/null 2>&1 || return 1
	[ -d "$GO_BIN_DIR" ] && [ -n "$(/usr/bin/find "$GO_BIN_DIR" -maxdepth 1 -type f 2>/dev/null)" ]
}

_go_report() {
	local b
	for b in "$GO_BIN_DIR"/*; do
		[ -x "$b" ] && [ -f "$b" ] || continue
		printf '%-14s %s\n' "$(basename "$b")" "$(_go_module "$b")"
	done
}

# The module information EMBEDDED in the binary. We do NOT guess: the origin is
# read exactly from here, so installing from the wrong repository is impossible.
# For the report "module + version" is enough; the path field that `go install`
# needs is read separately in _upd_go.
_go_module() {
	go version -m "$1" 2>/dev/null |
		awk '$1=="mod"{print $2" "$3; exit}'
}

# There is NO bulk update command for Go tools; `go install <main pkg>@latest`
# has to run once per tool.
_upd_go() {
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

# --- main flow ------------------------------------------------------------

apps_update() {
	local line id label present report_command update_command
	local missing=0 updated=0 index=0 total=0 skipped_count=0
	local -a lines=()
	mapfile -t lines < <(_channels)

	total=${#lines[@]}

	section "App channels (not managed by pacman) [$total channels]"

	for line in "${lines[@]}"; do
		[ -n "$line" ] || continue
		index=$((index + 1))
		IFS='|' read -r id label present report_command update_command <<<"$line"

		# Keep empty fields: read must not collapse them.
		case " ${SKIP_CHANNELS:-} " in
		*" $id "*)
			printf '\n  [%s/%s] %s — skipped via config\n' "$index" "$total" "$id"
			skipped_count=$((skipped_count + 1))
			continue
			;;
		esac

		# present = is the channel installed/runnable. docker uses
		# `docker info`: the binary can be installed while the daemon is down,
		# in which case the channel cannot work.
		if ! _run "$present" >/dev/null 2>&1; then
			printf '\n  [%s/%s] %s — not installed\n' "$index" "$total" "$id"
			missing=$((missing + 1))
			continue
		fi

		printf '\n  [%s/%s] %s — %s\n' "$index" "$total" "$id" "$label"
		report "$report_command"

		# No update command means this channel is INFORMATION ONLY.
		[ -n "$update_command" ] || continue

		confirm "Update $label?" || continue

		# Temporarily restore stdout/stderr to terminal so the update command
		# shows real-time progress (npm, pip, uv, go install all hide output
		# when they detect no TTY). fd 9 is the saved original terminal from
		# log_open(), so writing to it goes to both screen and tee→log.
		exec 1>&9 2>&9
		_run "$update_command"
		# Back to FIFO for subsequent logging.
		exec >"$_FIFO" 2>&1

		updated=$((updated + 1))
	done

	printf '\n================================\n'
	printf '==> %s channel(s) updated, %s absent, %s skipped by config.\n' \
		"$updated" "$missing" "$skipped_count"
	printf '================================\n\n\n'
	return 0
}
