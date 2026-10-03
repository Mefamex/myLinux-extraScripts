#!/usr/bin/env bash
# code channel — VS Code extensions

# Marketplace constants. Not settings: they describe a public API.
_VSCODE_API='https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery?api-version=7.1-preview.1'
_VSCODE_BATCH=100
_VSCODE_TIMEOUT=25

CHANNEL_ID="code"
CHANNEL_LABEL="VS Code extensions"
CHANNEL_PRESENT="command -v code"
CHANNEL_REPORT="@_ch_code_report"
CHANNEL_UPDATE="code --update-extensions"

# VS Code extensions that have a NEWER version on the marketplace.
_ch_code_report() {
	local installed ids total start payload resp latest line id cur want outdated=0

	installed=$(code --list-extensions --show-versions 2>/dev/null)
	[ -n "${installed//[[:space:]]/}" ] || return 0

	if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
		_ch_code_report_fallback "$installed" "curl or jq is not installed"
		return 0
	fi

	ids=$(printf '%s\n' "$installed" | sed 's/@[^@]*$//')
	total=$(printf '%s\n' "$ids" | grep -c .)
	latest=""

	# One request per 100 extensions.
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
		_ch_code_report_fallback "$installed" "the marketplace API did not answer"
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

# Used when the marketplace cannot be reached.
_ch_code_report_fallback() {
	local installed="$1" reason="$2"
	warn "cannot compare against the marketplace ($reason)"
	warn "listing what is installed instead — this is NOT the list of updates:"
	code --list-extensions --show-versions 2>/dev/null | sed 's/^/      /'
}
