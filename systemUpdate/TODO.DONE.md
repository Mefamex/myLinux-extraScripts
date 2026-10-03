# TODO.DONE

## Done

### 2026-10-04 Capture full update output in logs (terminal + log)
Restored `_run_tty` in `lib/log.sh` (was lost during modularization). Now writes update output to FIFO so `tee` captures it for both terminal (real-time) and log file. Verified: `--apps`, `--system`, `--status` all log update output. No ANSI escape codes in logs.

### 2026-10-04 Modular app channels (lib/apps/)
Created `lib/apps/` with `runner.sh`, `sort.conf`, and 16 channel files in `channels/`. Channels auto-discovered, sorted by `sort.conf` (with warning + alphabetic fallback), `SYSUPDATE_SKIP_CHANNELS` and `SYSUPDATE_GO_BIN_DIR` work. `--status`, `--apps`, `--all` all verified. Zero behavior change from monolithic version.

### 2026-10-03 Strip ANSI escape codes from logs
Added `sed -r 's/\x1b\[[0-9;]*m//g'` filter in `lib/log.sh` process substitution. Terminal keeps colors; log file gets clean text. Verified: no escape codes in logs, shellcheck passes.

### 2026-10-03 Log filename: add seconds
Changed log filename format from `systemUpdateYYYY-MM-DD-HH-MM.txt` to `systemUpdateYYYYMMDD-HHMMSS.txt` (includes seconds). Updated `lib/log.sh` and `README.md`. Verified `--status` and `--log` work with mixed old/new formats.

### 2026-10-03 Run one real update
User has run full updates and used the tool for several days. Confirm → update → log path verified working.

### 2026-10-03 Check the ~/.zshrc pointer
Section 10 already references `systemUpdate/systemUpdate.sh` correctly. Old `fullupdate`/`fulllog`/`_fullupdate` functions and `updatenoconfirm` alias noted as dropped. `zsh -n ~/.zshrc` clean.

### 2026-10-03 Remove the stale log directories
Removed `~/.local/state/updater/` (had 1 old log) and `~/.local/state/fullupdate/` (empty). Only `~/.local/state/systemUpdate/` remains.

### 2026-10-01 Rename to `systemUpdate`, all English
`guncelle/` → `systemUpdate/`; `systemUpdate.sh`; `SYSUPDATE_` environment
prefix. Code, comments, `--help`, file names, variable names and docs are all
English.

### 2026-10-01 Reports are never truncated (`MAX_REPORT_LINES` removed)
`MAX_REPORT_LINES` (default 12) is gone from `config`, `lib/config.sh`,
`lib/log.sh`, `lib/status.sh` and both READMEs.

Measured reason for removing it rather than raising it: the cap fired on exactly
ONE channel. It was not guarding a long report — it was hiding a *wrong* one.
The VS Code channel printed `code --list-extensions --show-versions`, which is
the inventory of everything installed (164 lines), not the list of what would
change. Most of those lines said "already installed".

`_code_report()` now compares installed versions against the public marketplace
API (`curl` + `jq`, batches of 100, ~3 s for 164 extensions) and prints only the
ones behind: measured **26 of 164**. The `code` CLI has no "outdated" flag, so
the API is the only source. If `curl`/`jq` are missing or the API does not
answer, the channel warns and falls back to the inventory — it never reports
"nothing to update" when it did not check.

The README previously claimed the full list survived into the log file. That was
**false**, and verified false: the log went through the same `head -n` path and
was truncated identically. The claim is gone now that nothing is truncated.

### 2026-10-01 Batch concatenation bug (found while adding the above)
`latest+=$(...)` strips the trailing newline, so with more than one batch the
last line of batch 1 ran into the first line of batch 2. Measured corruption:
`1.4.0ms-vscode.cpptools` — a version glued to the next extension's id. Fixed
with an explicit `$'\n'`.

### 2026-10-01 Log retention
`log_close()` prunes to the newest `LOG_KEEP` files (default 50). This is the
only place the tool deletes anything, and only ever its own log files (matching
`<label>*.txt`). A non-numeric `LOG_KEEP` is treated as "keep everything", so a
typo can never delete logs.

### 2026-10-01 `--status` and the AUR
`checkupdates` queries official repositories only, so AUR is opt-in via
`STATUS_AUR=1` (`yay -Qua`). AUR queries are network operations and can be slow;
making them opt-in preserves `--status` as a quick glance. Note `yay -Qua`
cannot report orphaned AUR packages either way.

### 2026-10-01 trap exit after SIGINT
Without an explicit `exit`, the INT trap let the script continue and exit rc=0
while the user believed it was cancelled. Fixed: `trap -` first, then
`log_close`, then `exit $sig`.

### 2026-10-01 Kernel detection (false positives)
The old `grep -E '^linux' | grep -v '^linux-firmware'` matched `linux-headers`,
`linux-api-headers` and `linux-wifi-hotspot`. Only packages that install under
`/usr/lib/modules/<version>/kernel/` are treated as the real kernel (measured:
`linux` matches, `linux-headers` installs only `build/` and matches 0).
Candidates come from `pacman -Qqo` (raw names) and the version from `pacman -Q`,
both locale-independent. Parsing the translated `pacman -Qo` output was removed
entirely.

### 2026-10-01 Parallel log name collisions
`[ -e "$f" ]` races under parallel starts (measured: 3 runs → 1 file). Fixed with
atomic reservation via `set -o noclobber`; 5 parallel runs then produced 5 files.

### 2026-10-01 FIFO left behind on SIGINT
`wait` hangs if a child still holds the FIFO open. Fixed by unlinking the FIFO
*before* waiting — `rm` removes the path without affecting open descriptors, and
`tee` then reaches EOF.

### 2026-10-01 Smaller fixes
`code --update-extensions` exists (confirmed in `code --help`), so the VS Code
channel needs no manual loop. `uv tool upgrade --all` is used. The `--status`
message was corrected to say the AUR is *not* included instead of claiming
everything is current.