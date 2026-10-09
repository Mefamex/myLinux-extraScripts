# =============================================================================
# systemReport — COMPLETED work log
#
# Written and maintained by @mefamex.
# =============================================================================
#
# Every item here was finished and verified. Ordered newest first, so the top
# of the file is the most recent work. The open list lives in todo.md.


# -----------------------------------------------------------------------------
# Current state
# -----------------------------------------------------------------------------
# version      5.1.0
# version date 2026-10-09
# shellcheck   clean (`shellcheck -x systemReport.sh lib/*.sh lib/sections/*.sh`)
# syntax       clean (`bash -n` on all 18 shell files)
# language     English only, by decision (see Notes in todo.md)
# tracked      VERSION, config, README.md, todo.md, TODO.DONE.md, lib/**


# =============================================================================
# 2026-10-09 — 5.1.0 feature round
# =============================================================================
# Four new features added, all tested and verified. Version bumped to 5.1.0.

## `--list` — print the section registry
- Prints a table of all ten sections (number, file name, title) and exits
  without collecting anything. Runs before config loading; needs no
  environment or settings.

## `--dry-run` — resolve paths, show what would happen, stop
- Resolves the report root, computes the report folder path and log path,
  checks sudo status, cleanup status, section filter and size cap.
- Prints all of it in the standard detail format, then exits 0.
- The report folder is NOT created; nothing on disk changes.
- Verified with `--only`, with sudo enabled and disabled, with cleanup on
  and off.

## `SECTION_SIZE_CAP` — per-section size cap
- Config setting (KB) and `SR_SIZE_CAP` environment variable. Default 0 = off.
- After a section file is written, its size is checked. If it exceeds the cap
  the file is truncated with `head -c` and a note is appended:
  `... [section truncated at N KB, ...]`.
- Validated in `load_config`: non-numeric values warn and fall back to 0.
- Tested: `SR_SIZE_CAP=1` on section 07 produced a 1096 B file with the
  truncation note at the end.

## `GZIP_OLD_REPORTS` — compress old reports instead of deleting
- Config setting and `SR_GZIP` environment variable. Default 0 = off.
- When enabled, `prune_old_reports` compresses each report beyond the keep
  limit into `<name>.tar.gz` via the new `_gzip_report` helper, then removes
  the original directory.
- Prints before/after sizes: `gzipped: name -> name.tar.gz  (4 -> 1 KB)`.
- If a `.tar.gz` with the same name already exists, the directory is deleted
  instead (with a warning). If `tar` fails, falls back to plain deletion so
  a compression problem never causes unbounded growth.
- Tested: 4 rapid runs with `SR_KEEP=2 SR_GZIP=1` produced 2 `.tar.gz`
  archives and 3 directories (current + 2 kept).

## Other changes
- `--list` and `--dry-run` added to the script header comment, so `--help`
  shows them.
- `config` file: `GZIP_OLD_REPORTS=0` and `SECTION_SIZE_CAP=0` added.
- `VERSION` bumped to 5.1.0 (2026-10-09).
- `README.md` updated: version, features, usage, settings table, environment
  variables table, version history.
- `bash -n` and `shellcheck -x` clean on all 18 shell files.


# =============================================================================
# 2026-10-09 — Independent verification pass
# =============================================================================
# Re-verified the 5.0.2 codebase after the initial machine-test round. No new
# bugs found. All documented behaviour reproduced; ShellCheck and bash -n
# still clean on all 18 files.

## Flags and arguments
- `--help` prints the leading comment block (awk pattern, not a sed range).
- `--version` / `-V` prints `systemReport 5.0.2 (2026-10-01)`, exit 0.
- `--only 00` runs only the named section, exit 0.
- `-o` with no value -> exit 1, `'-o' needs a directory.`
- `--only` with no value -> exit 1, needs a section list.
- `--keep abc` -> warns `must be a number, using 10`, run continues, exit 0.
- `--only 99` -> exit 1, `section not found: 99_* (valid: 00-09)`.
- `--only 3` -> exit 1, `invalid section number: '3' (two digits)`.
- `--only "01, 02"` -> exit 1, space detected, valid form shown.
- `--xyz` -> exit 2, `unknown argument: --xyz (--help)`.
- `SR_SUDO=0` as argument -> exit 2, recognised as env var, correct form shown.

## Environment and config
- `SR_REPORT_ROOT=/tmp/... SR_SUDO=no SR_CLEANUP=no` full unfiltered run
  produces all ten section files, terminal_log.txt and arch_full_report.txt.
- `SR_KEEP=1` with 3 rapid runs -> cleanup deletes old ones, never the
  current run's folder.
- `SR_CLEANUP=no` -> cleanup skipped, message printed.

## Report folder behaviour
- Same-second runs get `-2`, `-3` suffixes; no folder is overwritten.
- terminal_log.txt header carries version, author, host, kernel, start time.
- ANSI codes absent from terminal_log.txt.
- arch_full_report.txt contents table lists all ten sections with titles.
- Every section file non-empty; sizes consistent with the 5.0.2 baseline.

## Lint
- `bash -n` on all 18 shell files: clean.
- `shellcheck -x` on all 18 shell files: clean, zero output.


# =============================================================================
# 2026-10-01 — Machine-tested combinations (5.0.2 release round)
# =============================================================================
# Run on the real machine on 2026-10-01. Everything below was executed and the
# output read. Three real bugs came out of it, all fixed in 5.0.2.

## Arguments
- `--help`, `--version`, `-V`
- `--only 03,05,08` (sudo, password asked once)
- `-o /tmp/sr-test`
- `--keep 3` on the real root: 7 found, 3 kept, 4 deleted, all listed
- `--nosudo`, `--noclean`
- No filter at all: all ten section files produced

## Rejected input and exit codes
- `--only 99`             -> 1  section not found: 99_*  (valid: 00-09)
- `--only 3`              -> 1  invalid section number: '3' (two digits)
- `--only "01, 02"`       -> 1  space or missing number, valid form shown
- `--only` with no value  -> 1  needs a section list
- `-o` with no value      -> 1  needs a directory
- `SR_SUDO=0` as argument -> 2  recognised as an env var, correct form shown
- `--xyz`                 -> 2  unknown argument, points at --help
- `--keep abc`            -> 0  warns, falls back to 10, run continues

## Environment variables
- `SR_KEEP=20`                 honoured, limit shown as /20
- `SR_SUDO=no`                 honoured, checks needing root skipped
- `SR_CLEANUP=off`             honoured, cleanup skipped
- `SR_REPORT_ROOT=~/deneme`    resolved to /home/mfmx/deneme, tilde expanded
- `SR_LOG=/tmp/sr-paylasimli.log`  shared log, path shown in the summary
- `NO_COLOR=1`                 run completed, no ANSI in the log

## Sections individually
- All ten, one per run, plus a full unfiltered run. Every file non-empty:
  00 1402 B, 01 3625, 02 16216 (with sudo) / 15676 (without),
  03 5357, 04 7531, 05 4011, 06 11176, 07 16905 (with sudo) / 10756,
  08 19997, 09 4550.
- Combined report contents table lists all ten with correct titles.
- `02_hardware.txt` grows when sudo is available: 15676 -> 16216 bytes.
- Same-second runs get `-2`, `-3` suffixes and still sort correctly:
  `..._203750-2` is older than `..._203751`, and `-3` is newer than `-2`.

## Cleanup
- 3 fake old folders plus `--keep 2` -> 3 found, 2 kept, 1 deleted, listed.
- The current run's own folder was never deleted, in any run.

## Bugs found by this round, fixed in 5.0.2
- Trailing comma in "collecting only: 03,05,". `${var%,?}` cannot strip a
  trailing comma: in shell globbing `?` matches exactly one character, never
  zero, so the pattern does not match and nothing is removed. Changed to
  `${var%,}`. Found by reading the machine output; ShellCheck cannot see it.
- The same-timestamp warning printed between the banner and the path block.
  `create_report_dir` now only records the name in `REPORT_DIR_COLLIDED`;
  `systemReport.sh` prints it after the paths.
- `~` in `REPORT_ROOT` inside `config` does not expand. The file is sourced,
  so a quoted `~` stays a literal tilde and the path becomes
  `$HOME/~/...`. Documented in `config`: write `$HOME`, not `~`.


# =============================================================================
# 2026-10-01 — 5.0.2 documentation review
# =============================================================================
- `README.md` for the tool: purpose, features, usage, settings, structure,
  sections, version history, deliberate non-goals.
- Author credit in `README.md`, in the `systemReport.sh` header, in
  `VERSION`, and in every report header.
- Entry in the main repository `README.md`.
- Both READMEs read line by line against the files that exist (5.0.2).
  Corrected: version numbers, the missing `todo.md` in the structure tree,
  the `.gitignore` description, the `VERSION.txt` field list, the `~` vs
  `$HOME` pitfall in `config`, a "no masking" note in the non-goals, and the
  `todo.md` link in the main README.


# =============================================================================
# 2026-10-01 — 5.0.0 full English rewrite
# =============================================================================
# The single largest change in the project's history. Every user-facing string,
# variable name, comment and file name became English. The template config file
# was removed and `config` tracked directly.

## Restructure from the single-file version
- Split into `lib/` infrastructure modules plus one file per section.
- Section registry in one array, so adding a section touches two files:
  the module and the registry entry.
- Section modules only run commands. They know no file name, no header
  format and no redirection; all of that lives in `lib/report.sh`.
- ShellCheck clean from the start, not as a cleanup pass afterwards.

## Version system
- `VERSION` file is the only place a version number exists
  (`VERSION`, `VERSION_DATE`, `AUTHOR`).
- Version reaches: banner, `--version`, every section header, the combined
  report, the terminal log header, and the final summary.
- `VERSION_INFO` is the display form, `5.0.0 (2026-10-01)`.
- Bump rules documented in the file itself.

## Output location
- Output root resolved instead of hardcoded: `xdg-user-dir DOCUMENTS` →
  `XDG_DOCUMENTS_DIR` → `~/Documents` → `~/systemReport` → `.local/share`.
- No localised name ("Belgeler", "Dokumente") hardcoded anywhere.
- Home-directory backup added when Documents cannot be resolved.
- Resolved path printed at startup, so it is never a mystery.

## Reports and logs (5.0.1 refined this)
- One `arch_report_YYYYMMDD_HHMMSS/` folder per run, timestamp collision
  gets a `-2` suffix rather than overwriting.
- `arch_full_report.txt` merges every section, with a table of contents.
- `terminal_log.txt` written **inside each report folder**, ANSI stripped.
- Version, author, host and start time in the log header.
- Log directory created automatically; failure is reported, not swallowed.

## Settings
- `config` is tracked in the repository. No template file, no git-ignored
  personal copy, fresh clone runs as-is.
- English variable names: `REPORT_ROOT`, `KEEP_REPORTS`,
  `USE_SUDO_CHECKS`, `CLEANUP_ENABLED`, `LOG_FILE`.
- Environment overrides config, arguments override both.
- `KEEP_REPORTS` default 10.
- Wrong `SR_*=...` syntax after the script name is detected and explained.

## Cleanup
- Keep the newest N, delete the rest without asking, print what was deleted.
- The current run's own folder is never a candidate for deletion.
- Only `arch_report_*` directories directly under the report root.

## Sections
- Ten sections, English names, English content.
- `--only NN,NN` filter with validation: unknown number is an error, not a
  silently empty report.
- Missing tools reported in the report instead of leaving empty sections.
- Privileged checks skip gracefully and say so in the report.

## Output readability
- Boundaries are 2 or 3 rule lines, in code and in reports alike.
- `rule` / `rule_line` helpers in `lib/log.sh`, single width constant.
- Same treatment in `config`.


# =============================================================================
# Before 5.1.0 — earlier versions (summary)
# =============================================================================
# 3.1    single file; old folders deleted without asking; no version system.
# 4.0.0  modular rewrite; XDG-aware output root; terminal log added; `--only`;
#        keep-last-N; `VERSION.txt`.
# 5.0.0  full English rewrite; settings, code and output English only; template
#        removed and `config` tracked; home-directory backup for the output root;
#        2-3 line rules; keep count default 10; author credit.
# 5.0.1  terminal log back inside each report, with version and author in its
#        header; log directory created automatically.
# 5.0.2  first full pass of machine testing. Fixed: trailing comma in the
#        `--only` echo line, same-timestamp warning printed before the path
#        block, `~` in `REPORT_ROOT` documented as non-expanding in `config`.
# 5.1.0  `--list`, `--dry-run`, `SECTION_SIZE_CAP`, `GZIP_OLD_REPORTS`.
