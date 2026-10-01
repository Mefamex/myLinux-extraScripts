#!/usr/bin/env bash
#
# lib/report.sh — sourced file, DO NOT RUN DIRECTLY
#
# This file is `source`d by systemReport.sh. Running it on its own does
# nothing and dies on the variables it expects. The shebang is only there so the
# linter recognises the file as shell.
#
# systemReport — report.sh
#
# Writing section files and assembling the combined report.
#
# The division of labour matters here: section code runs commands and prints
# nothing to the console; all writing goes through write_section below. That way
# none of the ten section files knows a file name, a header format or a
# redirection, and all of that lives in one place.
#
# Depends on: $REPORT_DIR, $VERSION, $VERSION_DATE, $AUTHOR, $HOST_NAME, rule()

# Write one section to its file.
# $1 = section number (03), $2 = file name (03_storage.txt), $3 = title,
# remaining args = the function to run.
write_section() {
	local number="$1" file="$2" title="$3"
	shift 3

	local path="$REPORT_DIR/$file"

	section_progress "$number" "$title" "$file"

	{
		# A three-line rule opens the file. Section files are read by eye
		# in a text editor as often as by grep, and one thin line at the top
		# of a long file is easy to scroll straight past.
		rule 3 '='
		printf ' SECTION  : %s - %s\n' "$number" "$title"
		printf ' VERSION  : systemReport %s (%s)\n' "$VERSION" "$VERSION_DATE"
		printf ' AUTHOR   : %s\n' "$AUTHOR"
		printf ' DATE     : %s\n' "$(timestamp)"
		printf ' HOST     : %s\n' "$HOST_NAME"
		rule 2 '='
		printf '\n'
		"$@"
		printf '\n'
		rule 2 '='
	} 2>&1 | strip_ansi >"$path"
}

# Combine every section file into one flat report, with a table of contents.
# The report runs to tens of thousands of lines; being able to see which section
# is where without grepping for it is worth the dozen lines it costs.
merge_full_report() {
	local combined="$REPORT_DIR/arch_full_report.txt"
	local file name title

	{
		rule 3 '='
		printf ' ARCH LINUX SYSTEM REPORT\n'
		printf ' VERSION  : systemReport %s (%s)\n' "$VERSION" "$VERSION_DATE"
		printf ' AUTHOR   : %s\n' "$AUTHOR"
		printf ' DATE     : %s\n' "$(timestamp)"
		printf ' HOST     : %s\n' "$HOST_NAME"
		rule 2 '='

		printf '\n--- CONTENTS ---\n'
		for file in "$REPORT_DIR"/[0-9][0-9]_*.txt; do
			[ -e "$file" ] || continue
			name="$(basename "$file" .txt)"
			title="$(read_section_title "$name")"
			printf '  %-24s %s\n' "$name" "$title"
		done
		rule 2 '-'
		printf '\n'

		for file in "$REPORT_DIR"/[0-9][0-9]_*.txt; do
			[ -e "$file" ] || continue
			cat "$file"
			printf '\n'
		done

		rule 2 '='
		printf '=== End of report ===\n'
	} >"$combined"
}

# Read a section's title back out of the file it wrote.
#
# The title lives in the file's header as " SECTION  : 03 - Storage and Disks".
# It cannot be read with `head -n 1` because the first line is the rule
# ("========"). The header line is matched instead, and if that fails the file
# name is used: an empty cell in the contents table would be worse than a
# slightly less pretty one.
read_section_title() {
	local name="$1" line
	# grep -m1 stops at the first match, and the header is at the very top.
	line="$(grep -m1 '^ SECTION' "$REPORT_DIR/$name.txt" 2>/dev/null)" || line=''

	# " SECTION  : 03 - Storage and Disks" -> "Storage and Disks"
	line="${line#* - }"
	line="${line%"${line##*[![:space:]]}"}" # trim trailing whitespace

	[ -n "$line" ] || printf '%s' "${name%.txt}"
	printf '%s' "$line"
}
