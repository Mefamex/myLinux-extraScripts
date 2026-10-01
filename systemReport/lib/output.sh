#!/usr/bin/env bash
#
# lib/output.sh — sourced file, DO NOT RUN DIRECTLY
#
# This file is `source`d by systemReport.sh. Running it on its own does
# nothing and dies on the variables it expects. The shebang is only there so the
# linter recognises the file as shell.
#
# systemReport — output.sh
#
# Resolving the report root and creating the report folder.
#
# Why is this a chain of candidates rather than one path? XDG user directories
# are localised: the same machine may call it "Belgeler", "Documents",
# "Dokumente" or "Bureau" depending on locale and distribution. Hardcoding any
# one of them means reports land somewhere that does not exist on the next
# machine. So no localised name is hardcoded anywhere in this file; the
# candidates are tried in order and the one that won is printed.
#
# The chain always ends inside the home directory, so there is no state in which
# the script has nowhere to write. A missing Documents folder is a normal
# condition (minimal installs, containers, a fresh account), not an error, so it
# falls back instead of failing.
#
# Depends on: $REPORT_ROOT (from lib/config.sh), $REPORT_PREFIX, $REPORT_STAMP
# Sets:       $REPORT_ROOT (possibly rewritten), $REPORT_DIR, $ROOT_SOURCE

# Resolve the report root into $REPORT_ROOT.
#
# Precedence: config / environment -> xdg-user-dir -> user-dirs.dirs -> English
# names -> home backup -> XDG data dir. A relative path is resolved against $HOME
# so the answer does not depend on the working directory. An explicit path is
# created if missing and checked for write access, rather than failing later with
# a confusing "permission denied" halfway through the run.
resolve_report_root() {
	local root="$REPORT_ROOT" candidate source=''

	if [ -n "$root" ]; then
		case "$root" in
		/*) ;;
		*) root="$HOME/$root" ;;
		esac
		# Strip trailing slashes so path comparisons stay simple.
		while [ "${root%/}" != "$root" ] && [ "$root" != '/' ]; do root="${root%/}"; done

		if ! mkdir -p -- "$root" 2>/dev/null; then
			err "cannot create report root: $root"
			return 1
		fi
		[ -w "$root" ] || {
			err "report root is not writable: $root"
			return 1
		}
		REPORT_ROOT="$root"
		return 0
	fi

	# 1. xdg-user-dir: returns the user's real documents directory.
	if command -v xdg-user-dir >/dev/null 2>&1; then
		candidate="$(xdg-user-dir DOCUMENTS 2>/dev/null)"
		# When no documents directory is configured, xdg-user-dir prints
		# $HOME. That is not a useful answer, so it is discarded.
		if [ -n "$candidate" ] && [ "$candidate" != "$HOME" ] && [ -d "$candidate" ]; then
			root="$candidate/systemReport"
			source="xdg-user-dir DOCUMENTS"
		fi
	fi

	# 2. user-dirs.dirs: fallback when xdg-user-dir is missing or unhelpful.
	if [ -z "$root" ] && [ -r "$HOME/.config/user-dirs.dirs" ]; then
		# shellcheck disable=SC1091
		. "$HOME/.config/user-dirs.dirs" 2>/dev/null || true
		candidate="${XDG_DOCUMENTS_DIR:-}"
		# The file stores the path home-relative, shell-quoted.
		candidate="${candidate/#\$HOME/$HOME}"
		if [ -n "$candidate" ] && [ -d "$candidate" ]; then
			root="$candidate/systemReport"
			source="XDG_DOCUMENTS_DIR"
		fi
		unset XDG_DOCUMENTS_DIR
	fi

	# 3. English names: the most consistent thing on otherwise unusual systems.
	if [ -z "$root" ]; then
		for candidate in "$HOME/Documents" "$HOME/Document"; do
			if [ -d "$candidate" ]; then
				root="$candidate/systemReport"
				source="English name"
				break
			fi
		done
	fi

	# 4. Backup inside the home directory. Deliberately not hidden: when
	# Documents could not be resolved at all, the user still wants to find the
	# reports without guessing, and a plain name in the home directory is the
	# one place they will look first.
	if [ -z "$root" ]; then
		root="$HOME/systemReport"
		source="home directory (backup)"
	fi

	# Create it, and fall back to 5 only if that genuinely fails. Testing the
	# directory with -d before choosing it would be wrong: it does not exist
	# yet on the first run, which is exactly the run that matters.
	if ! mkdir -p -- "$root" 2>/dev/null || [ ! -w "$root" ]; then
		# 5. Last resort: XDG data dir. It exists on every account and its
		# name is not localised, so it is the one candidate that never needs
		# a localised name to be guessed.
		root="$HOME/.local/share/systemReport"
		source=".local/share (last resort)"
		if ! mkdir -p -- "$root" 2>/dev/null; then
			err "cannot create report root: $root"
			return 1
		fi
		[ -w "$root" ] || {
			err "report root is not writable: $root"
			return 1
		}
	fi

	REPORT_ROOT="$root"
	# shellcheck disable=SC2034  # ROOT_SOURCE is read by systemReport.sh
	ROOT_SOURCE="$source"
	return 0
}

# Create the folder for this run.
#
# If a folder with the same timestamp already exists, a numeric suffix is
# appended rather than reusing it. Overwriting an existing report because two
# runs started in the same second is the worst possible failure mode here: the
# old data would be gone and nothing would say so.
create_report_dir() {
	local dir first="$REPORT_ROOT/${REPORT_PREFIX}_$REPORT_STAMP"

	dir="$first"
	REPORT_DIR_COLLIDED=false
	if [ -e "$dir" ]; then
		local n=2
		while [ -e "$REPORT_ROOT/${REPORT_PREFIX}_$REPORT_STAMP-$n" ] && [ "$n" -lt 100 ]; do
			n=$((n + 1))
		done
		dir="$REPORT_ROOT/${REPORT_PREFIX}_$REPORT_STAMP-$n"
		# Only recorded here. The warning is printed by systemReport.sh after
		# the startup block, so the paths the user needs to read are not
		# interrupted by a note about the folder name.
		# shellcheck disable=SC2034  # REPORT_DIR_COLLIDED is read in systemReport.sh
		REPORT_DIR_COLLIDED="${dir##*/}"
	fi

	if ! mkdir -p -- "$dir"; then
		err "cannot create report folder: $dir"
		return 1
	fi

	# shellcheck disable=SC2034  # REPORT_DIR is read by systemReport.sh
	REPORT_DIR="$dir"
	return 0
}
