# =============================================================================
# systemReport — TODO, notes and decisions
#
# Written and maintained by @mefamex.
# =============================================================================
#
# A working list, not documentation. The user-facing docs live in README.md;
# this file exists so the state of the work and the reasoning behind it are not
# lost between sessions.
#
#   [x] done
#   [ ] open
#   [!] known limit, deliberately not fixed


# -----------------------------------------------------------------------------
# Current state
# -----------------------------------------------------------------------------
# version      5.0.2
# version date 2026-10-01
# shellcheck   clean (`shellcheck -x systemReport.sh lib/*.sh lib/sections/*.sh`)
# syntax       clean (`bash -n` on all 18 shell files)
# language     English only, by decision (see Notes)
# tracked      VERSION, config, README.md, todo.md, .gitignore, lib/**


# -----------------------------------------------------------------------------
# [x] Done
# -----------------------------------------------------------------------------

## Restructure from the single-file version
- [x] Split into `lib/` infrastructure modules plus one file per section.
- [x] Section registry in one array, so adding a section touches two files:
      the module and the registry entry.
- [x] Section modules only run commands. They know no file name, no header
      format and no redirection; all of that lives in `lib/report.sh`.
- [x] ShellCheck clean from the start, not as a cleanup pass afterwards.

## Version system
- [x] `VERSION` file is the only place a version number exists
      (`VERSION`, `VERSION_DATE`, `AUTHOR`).
- [x] Version reaches: banner, `--version`, every section header, the combined
      report, `VERSION.txt`, the terminal log header, and the final summary.
- [x] `VERSION_INFO` is the display form, `5.0.2 (2026-10-01)`.
- [x] Bump rules documented in the file itself.

## Output location
- [x] Output root resolved instead of hardcoded: `xdg-user-dir DOCUMENTS` →
      `XDG_DOCUMENTS_DIR` → `~/Documents` → `~/systemReport` → `.local/share`.
- [x] No localised name ("Belgeler", "Dokumente") hardcoded anywhere.
- [x] Home-directory backup added when Documents cannot be resolved.
- [x] Resolved path printed at startup, so it is never a mystery.

## Reports and logs
- [x] One `arch_report_YYYYMMDD_HHMMSS/` folder per run, timestamp collision
      gets a `-2` suffix rather than overwriting.
- [x] `arch_full_report.txt` merges every section, with a table of contents.
- [x] `terminal_log.txt` written **inside each report folder**, ANSI stripped.
- [x] Version, author, host and start time in the log header.
- [x] Log directory created automatically; failure is reported, not swallowed.

## Settings
- [x] `config` is tracked in the repository. No template file, no git-ignored
      personal copy, fresh clone runs as-is.
- [x] English variable names: `REPORT_ROOT`, `KEEP_REPORTS`,
      `USE_SUDO_CHECKS`, `CLEANUP_ENABLED`, `LOG_FILE`.
- [x] Environment overrides config, arguments override both.
- [x] `KEEP_REPORTS` default 10.
- [x] Wrong `SR_*=...` syntax after the script name is detected and explained.

## Cleanup
- [x] Keep the newest N, delete the rest without asking, print what was deleted.
- [x] The current run's own folder is never a candidate for deletion.
- [x] Only `arch_report_*` directories directly under the report root.

## Sections
- [x] Ten sections, English names, English content.
- [x] `--only NN,NN` filter with validation: unknown number is an error, not a
      silently empty report.
- [x] Missing tools reported in the report instead of leaving empty sections.
- [x] Privileged checks skip gracefully and say so in the report.

## Output readability
- [x] Boundaries are 2 or 3 rule lines, in code and in reports alike.
- [x] `rule` / `rule_line` helpers in `lib/log.sh`, single width constant.
- [x] Same treatment in `config`.

## Documentation
- [x] `README.md` for the tool: purpose, features, usage, settings, structure,
      sections, version history, deliberate non-goals.
- [x] Author credit in `README.md`, in the `systemReport.sh` header, in
      `VERSION`, and in every report header.
- [x] Entry in the main repository `README.md`.
- [x] Both READMEs read line by line against the files that exist (5.0.2).
      Corrected: version numbers, the missing `todo.md` in the structure tree,
      the `.gitignore` description, the `VERSION.txt` field list, the `~` vs
      `$HOME` pitfall in `config`, a "no masking" note in the non-goals, and the
      `todo.md` link in the main README.


# -----------------------------------------------------------------------------
# [x] Machine-tested combinations
# -----------------------------------------------------------------------------
# Run on the real machine on 2026-10-01. Everything below was executed and the
# output read. Three real bugs came out of it, all fixed in 5.0.2.

## Arguments
- [x] `--help`, `--version`, `-V`
- [x] `--only 03,05,08` (sudo, password asked once)
- [x] `-o /tmp/sr-test`
- [x] `--keep 3` on the real root: 7 found, 3 kept, 4 deleted, all listed
- [x] `--nosudo`, `--noclean`
- [x] No filter at all: all ten section files produced

## Rejected input and exit codes
- [x] `--only 99`             -> 1  section not found: 99_*  (valid: 00-09)
- [x] `--only 3`              -> 1  invalid section number: '3' (two digits)
- [x] `--only "01, 02"`       -> 1  space or missing number, valid form shown
- [x] `--only` with no value  -> 1  needs a section list
- [x] `-o` with no value      -> 1  needs a directory
- [x] `SR_SUDO=0` as argument -> 2  recognised as an env var, correct form shown
- [x] `--xyz`                 -> 2  unknown argument, points at --help
- [x] `--keep abc`            -> 0  warns, falls back to 10, run continues

## Environment variables
- [x] `SR_KEEP=20`                 honoured, limit shown as /20
- [x] `SR_SUDO=no`                 honoured, checks needing root skipped
- [x] `SR_CLEANUP=off`             honoured, cleanup skipped
- [x] `SR_REPORT_ROOT=~/deneme`    resolved to /home/mfmx/deneme, tilde expanded
- [x] `SR_LOG=/tmp/sr-paylasimli.log`  shared log, path shown in the summary
- [x] `NO_COLOR=1`                 run completed, no ANSI in the log

## Sections individually
- [x] All ten, one per run, plus a full unfiltered run. Every file non-empty:
      00 1402 B, 01 3625, 02 16216 (with sudo) / 15676 (without),
      03 5357, 04 7531, 05 4011, 06 11176, 07 16905 (with sudo) / 10756,
      08 19997, 09 4550.
- [x] Combined report contents table lists all ten with correct titles.
- [x] `02_hardware.txt` grows when sudo is available: 15676 -> 16216 bytes.
- [x] Same-second runs get `-2`, `-3` suffixes and still sort correctly:
      `..._203750-2` is older than `..._203751`, and `-3` is newer than `-2`.

## Cleanup
- [x] 3 fake old folders plus `--keep 2` -> 3 found, 2 kept, 1 deleted, listed.
- [x] The current run's own folder was never deleted, in any run.

## Bugs found by this round, fixed in 5.0.2
- [x] Trailing comma in "collecting only: 03,05,". `${var%,?}` cannot strip a
      trailing comma: in shell globbing `?` matches exactly one character, never
      zero, so the pattern does not match and nothing is removed. Changed to
      `${var%,}`. Found by reading the machine output; ShellCheck cannot see it.
- [x] The same-timestamp warning printed between the banner and the path block.
      `create_report_dir` now only records the name in `REPORT_DIR_COLLIDED`;
      `systemReport.sh` prints it after the paths.
- [x] `~` in `REPORT_ROOT` inside `config` does not expand. The file is sourced,
      so a quoted `~` stays a literal tilde and the path becomes
      `$HOME/~/...`. Documented in `config`: write `$HOME`, not `~`.


# -----------------------------------------------------------------------------
# [ ] Open
# -----------------------------------------------------------------------------
# Ordered by what is most useful to do next.

## 1. Still untested
- [ ] Wrong password on purpose. The attempt that should have covered this
      actually succeeded, so the "sudo validation failed" path is still unproven
      on a real machine. Needs a genuinely wrong password, then a check for
      `skipped (needs root)` in THAT run's folder, not an older one.
- [ ] `SR_CONFIG=/tmp/other` — the alternate config file was never exercised.
- [ ] A run where every root-requiring check actually succeeds, confirming
      `dmidecode`, `fdisk`, `smartctl`, `dmesg` and `efibootmgr` all produce
      output and none of them is silently empty.

## 2. Commit
- [x] Done in `a304b4f`. `systemReport/` plus the `README.md` entry only;
      `systemUpdate/` was left alone in the working tree.

## 3. Things that could be added later
- [ ] `--list` to print the section registry without collecting anything.
- [ ] `--dry-run` that resolves all paths, prints them and stops.
- [ ] Per-section size cap. The report is tens of thousands of lines and the
      logs section is the largest part.
- [ ] Optional gzip of reports older than the newest N.
- [ ] Warn when a section produces an implausibly small file, which usually
      means a tool silently returned nothing. Machine testing gave 1402 B for
      `00_privacy.txt`, which is the floor to compare against.


# -----------------------------------------------------------------------------
# [!] Known limits, deliberately not fixed
# -----------------------------------------------------------------------------
# - `find -printf` and `stat -c` are GNU coreutils. Fine on Arch, would break on
#   busybox or BSD. The tool is declared Arch-only, so this is a choice.
# - Cleanup trusts folder names for ordering. A wrong system clock puts a report
#   at the wrong end of the sort. Mitigated by never deleting the current run's
#   folder, not eliminated.
# - `pacman` operations are not run, only queried. Nothing in this tool changes
#   system state.
# - The report is not redacted. Privacy is handled by telling the user which
#   files to look at, not by masking values, because masking silently produces
#   a report that looks complete and is not.


# -----------------------------------------------------------------------------
# Notes and decisions
# -----------------------------------------------------------------------------
# English only. Asked for explicitly, twice. Nothing is localised: no Turkish
# variable names, no Turkish comments, no Turkish file names, no Turkish
# boolean spellings. Reason beyond the request: a report is compared between
# machines, and localisation would make two reports from the same tool differ
# for no reason.
#
# `config` is tracked. It was originally a template plus a git-ignored personal
# copy. That split meant the shipped defaults were invisible to a reviewer and a
# fresh clone needed a run before it worked. One tracked file is easier to
# review and easier to reproduce.
#
# The terminal log goes inside the report. It was briefly a fixed shared path,
# which was wrong: the log is most often pasted into a chat message, and it has
# to be able to say which version produced it and stand alone. A fixed path also
# mixes runs together, which defeats the point of a per-run report folder.
#
# Three-line rules at major transitions, two-line at minor ones. One line was too
# thin to register while output scrolls past. Three identical lines everywhere
# was too noisy, hence two levels.
#
# No personal value in the code. No hardcoded host name, network name or device
# name, so the repository carries nothing machine-specific.
#
# Module naming is English too: `lib/sections/`, not `lib/bolumler/`. Part of the
# same English-only decision.


# -----------------------------------------------------------------------------
# History
# -----------------------------------------------------------------------------
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