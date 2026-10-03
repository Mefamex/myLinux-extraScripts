#!/usr/bin/env bash
#
# lib/apps/runner.sh — source file, NOT meant to be run directly
#
# systemUpdate — apps runner
#
# Discovers channel files in channels/, loads them, sorts by sort.conf,
# and runs the update flow. Replaces the monolithic apps_update().
#
# Depends on: section/warn/info/report/confirm/_run/_run_tty (lib/log.sh),
#             $SKIP_CHANNELS, $GO_BIN_DIR (lib/config.sh)

# --- configuration ---------------------------------------------------------

_APPS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

# --- load sort order -------------------------------------------------------

_load_sort_order() {
	local sort_file="$_APPS_DIR/sort.conf"
	SORT_ORDER=()
	if [ -f "$sort_file" ]; then
		local line
		while IFS= read -r line; do
			# Strip comments and whitespace
			line="${line%%#*}"
			line="${line//[[:space:]]/}"
			[ -n "$line" ] && SORT_ORDER+=("$line")
		done <"$sort_file"
	else
		warn "sort.conf not found, using alphabetic channel order"
	fi
}

# --- discover and load channel files ---------------------------------------

_load_channels() {
	local f

	# Build sort_index: CHANNEL_ID -> position in SORT_ORDER (first occurrence wins)
	local -A sort_index=()
	local i=0
	for id in "${SORT_ORDER[@]}"; do
		[ -z "${sort_index[$id]:-}" ] && sort_index[$id]=$i
		((i++))
	done

	# Warn on duplicates in sort.conf
	local seen=()
	for id in "${SORT_ORDER[@]}"; do
		local found=0
		for s in "${seen[@]}"; do
			[ "$s" = "$id" ] && found=1 && break
		done
		if [ "$found" -eq 1 ]; then
			warn "sort.conf: duplicate ID '$id' (ignored)"
		else
			seen+=("$id")
		fi
	done

	# Discover channel files
	CHANNELS_ID=()
	CHANNELS_LABEL=()
	CHANNELS_PRESENT=()
	CHANNELS_REPORT=()
	CHANNELS_UPDATE=()
	CHANNELS_SORT=()

	for f in "$_APPS_DIR/channels"/*.sh; do
		[ -f "$f" ] || continue
		# shellcheck source=/dev/null
		. "$f"

		# Validate required variables
		[ -n "${CHANNEL_ID:-}" ] || {
			warn "Missing CHANNEL_ID in $f"
			continue
		}
		[ -n "${CHANNEL_LABEL:-}" ] || {
			warn "Missing CHANNEL_LABEL in $f"
			continue
		}
		[ -n "${CHANNEL_PRESENT:-}" ] || {
			warn "Missing CHANNEL_PRESENT in $f"
			continue
		}
		[ -n "${CHANNEL_REPORT:-}" ] || {
			warn "Missing CHANNEL_REPORT in $f"
			continue
		}
		# CHANNEL_UPDATE can be empty (report-only)
		# shellcheck disable=SC2153  # CHANNEL_UPDATE is set by sourced channel file

		# Store metadata
		CHANNELS_ID+=("$CHANNEL_ID")
		CHANNELS_LABEL+=("$CHANNEL_LABEL")
		CHANNELS_PRESENT+=("$CHANNEL_PRESENT")
		CHANNELS_REPORT+=("$CHANNEL_REPORT")
		# shellcheck disable=SC2153  # CHANNEL_UPDATE is set by sourced channel file
		CHANNELS_UPDATE+=("$CHANNEL_UPDATE")
		# Sort key: position in sort.conf, or 9999 for unlisted (alphabetic later)
		CHANNELS_SORT+=("${sort_index[$CHANNEL_ID]:-9999}")
	done

	# Warn on unknown IDs in sort.conf
	for id in "${SORT_ORDER[@]}"; do
		[[ " ${CHANNELS_ID[*]} " =~ $id ]] || warn "sort.conf: unknown channel ID '$id' (ignored)"
	done
}

# --- sort channels ---------------------------------------------------------

_sort_channels() {
	local n=${#CHANNELS_ID[@]}
	local -a indices=()
	local i

	# Create index array 0..n-1
	for ((i = 0; i < n; i++)); do
		indices+=("$i")
	done

	# Decorated sort: sort by CHANNELS_SORT then CHANNEL_ID
	# Using bubble sort since n is small (16)
	local swapped=1 j tmp
	while [ "$swapped" -eq 1 ]; do
		swapped=0
		for ((j = 0; j < n - 1; j++)); do
			local a=${indices[j]} b=${indices[j + 1]}
			if [ "${CHANNELS_SORT[a]}" -gt "${CHANNELS_SORT[b]}" ] ||
				{ [ "${CHANNELS_SORT[a]}" -eq "${CHANNELS_SORT[b]}" ] &&
					[[ "${CHANNELS_ID[a]}" > "${CHANNELS_ID[b]}" ]]; }; then
				tmp=${indices[j]}
				indices[j]=${indices[j + 1]}
				indices[j + 1]=$tmp
				swapped=1
			fi
		done
	done

	# Reorder arrays according to sorted indices
	local -a sorted_id=() sorted_label=() sorted_present=() sorted_report=() sorted_update=()
	for i in "${indices[@]}"; do
		sorted_id+=("${CHANNELS_ID[i]}")
		sorted_label+=("${CHANNELS_LABEL[i]}")
		sorted_present+=("${CHANNELS_PRESENT[i]}")
		sorted_report+=("${CHANNELS_REPORT[i]}")
		sorted_update+=("${CHANNELS_UPDATE[i]}")
	done

	CHANNELS_ID=("${sorted_id[@]}")
	CHANNELS_LABEL=("${sorted_label[@]}")
	CHANNELS_PRESENT=("${sorted_present[@]}")
	CHANNELS_REPORT=("${sorted_report[@]}")
	CHANNELS_UPDATE=("${sorted_update[@]}")
}

# --- main flow -------------------------------------------------------------

apps_update() {
	_load_sort_order
	_load_channels
	_sort_channels

	local total=${#CHANNELS_ID[@]}
	local index=0 missing=0 updated=0 skipped_count=0
	local -a deferred=()
	local update_all=0

	section "App channels (not managed by pacman) [$total channels]"

	for ((index = 0; index < total; index++)); do
		local id="${CHANNELS_ID[index]}"
		local label="${CHANNELS_LABEL[index]}"
		local present="${CHANNELS_PRESENT[index]}"
		local report_command="${CHANNELS_REPORT[index]}"
		local update_command="${CHANNELS_UPDATE[index]}"

		# Skip via config
		case " ${SKIP_CHANNELS:-} " in
		*" $id "*)
			printf '\n  [%s/%s] %s — skipped via config\n' "$((index + 1))" "$total" "$id"
			skipped_count=$((skipped_count + 1))
			continue
			;;
		esac

		# Check if channel is present/usable
		if ! _run "$present" >/dev/null 2>&1; then
			printf '\n  [%s/%s] %s — not installed\n' "$((index + 1))" "$total" "$id"
			missing=$((missing + 1))
			continue
		fi

		printf '\n  [%s/%s] %s — %s\n' "$((index + 1))" "$total" "$id" "$label"
		report "$report_command"

		# No update command = report-only channel
		[ -n "$update_command" ] || continue

		# Skip confirm if update_all is set
		if [ "$update_all" -eq 1 ]; then
			if _run_tty "$update_command"; then
				updated=$((updated + 1))
			else
				warn "update failed: $update_command"
			fi
			continue
		fi

		confirm "Update $label?"
		case "$?" in
		0) ;;          # yes, run now
		1) continue ;; # skip
		2)             # defer
			deferred+=("$index")
			continue
			;;
		3) # update this + all remaining
			update_all=1
			;;
		4) # quit
			return 0
			;;
		esac

		if _run_tty "$update_command"; then
			updated=$((updated + 1))
		else
			warn "update failed: $update_command"
		fi
	done

	# Process deferred channels
	for index in "${deferred[@]}"; do
		local id="${CHANNELS_ID[index]}"
		local label="${CHANNELS_LABEL[index]}"
		local report_command="${CHANNELS_REPORT[index]}"
		local update_command="${CHANNELS_UPDATE[index]}"

		printf '\n  [deferred] %s — %s\n' "$id" "$label"
		report "$report_command"
		confirm "Update $label?"
		case $? in
		0) ;;
		1 | 2) continue ;;
		3) update_all=1 ;;
		4) return 0 ;;
		esac
		if _run_tty "$update_command"; then
			updated=$((updated + 1))
		else
			warn "update failed: $update_command"
		fi
	done

	printf '\n================================\n'
	printf '==> %s channel(s) updated, %s absent, %s skipped by config.\n' \
		"$updated" "$missing" "$skipped_count"
	printf '================================\n\n\n'
	return 0
}

# --- initialization --------------------------------------------------------

_load_sort_order
_load_channels
_sort_channels
