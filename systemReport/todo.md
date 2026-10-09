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
# Completed work has moved to TODO.DONE.md (newest first).
#
#   [x] done      -> see TODO.DONE.md
#   [ ] open
#   [!] known limit, deliberately not fixed


# -----------------------------------------------------------------------------
# Current state
# -----------------------------------------------------------------------------
# version      5.1.0
# version date 2026-10-09
# shellcheck   clean (`shellcheck -x systemReport.sh lib/*.sh lib/sections/*.sh`)
# syntax       clean (`bash -n` on all 18 shell files)
# language     English only, by decision (see Notes)
# tracked      VERSION, config, README.md, todo.md, TODO.DONE.md, lib/**
# last audit   2026-10-09 — 5.1.0 feature round + verification pass


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

## 2. Findings from the 2026-10-09 audit (recommendations, not bugs)
# No functional bugs were found. The items below are code-quality or
# robustness improvements worth considering.

- [ ] `lib/config.sh` — `~` inside a quoted value in `config` is not expanded
      (the file is sourced). Currently documented as a known pitfall. Could be
      improved by expanding a leading `~` after sourcing, so the shipped
      config can use either `~` or `$HOME` without surprises.
- [ ] `lib/log.sh` — `RULE_WIDTH=64` is hardcoded. Could derive from
      `COLUMNS` or `tput cols` so rules span the terminal on wider screens.
      Must stay at 64 when not a terminal (log file must not change width).
- [ ] `lib/sudo.sh` — `fix_report_ownership` only fixes ownership when
      `REPORT_ROOT == $HOME/systemReport`. If the user sets a custom root
      under their own home (e.g. `-o ~/reports`), ownership is not fixed when
      running under `sudo -u`. Could check "is REPORT_ROOT under $home"
      instead of exact equality.
- [ ] `systemReport.sh` line ~382 — the `${SECTION_FILTER%,}` strip is correct
      but non-obvious (a previous bug used `${var%,?}` which never matches).
      A one-line comment explaining why `,?` is wrong would prevent a
      regression.
- [ ] `lib/report.sh` — warn when a section file is implausibly small
      (e.g. < 500 bytes), which usually means a tool silently returned
      nothing. `00_privacy.txt` at 1402 B is the known floor.


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
# thin to register as output scrolls past. Three identical lines everywhere
# was too noisy, hence two levels.
#
# No personal value in the code. No hardcoded host name, network name or device
# name, so the repository carries nothing machine-specific.
#
# Module naming is English too: `lib/sections/`, not `lib/bolumler/`. Part of
# the same English-only decision.
#
# Completed work moved to TODO.DONE.md on 2026-10-09 so the open list stays
# short and scannable. TODO.DONE.md is ordered newest first.


# -----------------------------------------------------------------------------
# History (short; full log in TODO.DONE.md)
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
# 5.1.0  `--list`, `--dry-run`, `SECTION_SIZE_CAP`, `GZIP_OLD_REPORTS`.
