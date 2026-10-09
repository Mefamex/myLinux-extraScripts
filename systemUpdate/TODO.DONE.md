# TODO.DONE

## Done

### 2026-10-09 SYSUPDATE_CONFIG documented in README
The "Settings" table already listed the five settings with their env vars; the
`SYSUPDATE_CONFIG` path override was only mentioned in lib/config.sh's header
and is now documented in README too. TODO item "Document all SYSUPDATE_* env
vars in one place" closed.

### 2026-10-09 Composer channel no longer errors without a global composer.json
`composer global show -N` failed loudly (rc=1, "could not find composer.json",
plus a `!! report command failed` line) whenever composer exists but no global
packages were ever installed. CHANNEL_PRESENT in composer.sh now requires
composer AND a global composer.json, resolving the composer home the same way
composer itself does (`COMPOSER_HOME` env → `~/.composer` legacy fallback →
`$XDG_CONFIG_HOME|~/.config/composer`). The channel now reports "not
installed" cleanly. Tested: no composer.json → absent; COMPOSER_HOME with a
require section → present; empty require → present, nothing to update.

### 2026-10-09 sort.conf edge cases verified; duplicate warnings removed
Verified on a throwaway copy of the tool: duplicate IDs warn and the first
occurrence wins, unknown IDs warn (exact match), a missing sort.conf warns and
falls back to alphabetic order, comment/empty lines parse cleanly. While
verifying, the redundant `_load_sort_order`/`_load_channels`/`_sort_channels`
calls at the end of runner.sh were removed — nothing outside runner.sh reads
the channel arrays (verified by grep), and every sort.conf warning used to
print TWICE (once at source time, once inside apps_update).

### 2026-10-09 _run_tty exit code verified
The TODO worried _run_tty might return 0 on pipefail pipelines. Verified with
a harness: `false` → 1, `true` → 0, `false | true` (pipefail) → 1,
`true | true` → 0. The command's exit code propagates correctly; the item is
closed.

### 2026-10-09 Full script audit (see TODO.md "Bugs found in review")
Reviewed the whole tool: `bash -n` + `shellcheck` clean (apart from known
SC2034/SC2329 noise), ran `--status` end-to-end, verified every channel's
update/report command exists in its `--help`, measured config precedence,
GO_BIN_DIR resolution, SIGINT cleanup (rc=130, log footer written, FIFO dir
removed) and pipe-to-`head` behavior. Findings and still-open items live in
TODO.md; the fixes from the audit are the entries below.

### 2026-10-09 Docs rewritten to match reality
README.md, NOTES.md, MODULAR_APPS_PLAN.md and TODO.md re-edited after the
audit: `.gitignore` row removed (the file does not exist in the repo), "every
line commented out" claims corrected (the tracked `config` ships active
values), the NOTES cascade now matches `resolve_log_dir()` (the
`~/.config/user-dirs.dirs` step was never implemented and is gone), the
`systemUpdate.sh` header says "same second" (was "same minute"), and
MODULAR_APPS_PLAN.md is marked as implemented with the deviations noted.

### 2026-10-09 Unknown-ID check in sort.conf is now exact
`runner.sh` checked unknown IDs with a regex (`[[ ... =~ $id ]]`), so an ID
like `pip` could silently match a `pipx` channel and suppress the warning.
Replaced with an exact string comparison over `CHANNELS_ID`.

### 2026-10-09 Runner no longer reuses stale channel variables
A channel file that forgot a variable kept the PREVIOUS file's value, and
under `set -u` a missing `CHANNEL_UPDATE` could crash the run. Worse, before
that crash a wrong inherited value could silently run the WRONG update command.
`_load_channels()` now unsets `CHANNEL_ID/LABEL/PRESENT/REPORT/UPDATE` before
sourcing each file and stores `CHANNEL_UPDATE` via `${CHANNEL_UPDATE:-}`
(missing = report-only, same as an explicit `""`).

### 2026-10-09 Deferred channels no longer report twice
`runner.sh` ran `report` inside the deferred loop even though the same report
had already run before the `a` (defer) answer in the main loop. The duplicate
call is gone.

### 2026-10-09 System-scope confirmation no longer advertises a/A/q
`confirm()` takes an options argument (default `y/N/a/A/q`); the firmware step
in `lib/system.sh` now prompts `[y/N]` only. Previously the prompt offered
`a`/`A`/`q` in the system scope, where those answers were silently treated as
"no" — a user pressing `q` expected an abort and got a skip.

### 2026-10-09 SIGPIPE no longer kills the script (piping output is safe)
`./systemUpdate.sh --status | head` used to kill the shell: the consumer
closing early made tee die of SIGPIPE, which killed bash before the EXIT trap
ran — leaking a temp FIFO dir in `/tmp` and leaving a log without its footer
(both measured). `systemUpdate.sh` now ignores SIGPIPE (`trap '' PIPE`), so a
closed consumer is a plain EPIPE write error instead of a death, and
`_run_tty()` stops reopening the FIFO once its reader (tee) is gone. Verified:
`.. | head -3` completes with rc=0, the log file is complete, no temp dir is
left behind.

### 2026-10-09 GO_BIN_DIR no longer collapses to an empty string
`go env GOBIN` prints an empty line with rc=0 when GOBIN is unset, so the old
`|| printf` fallback never fired and GO_BIN_DIR became "" — then `-d ""`
failed and the go channel reported "not installed" despite installed tools.
`config_load()` now treats an empty `go env` result as "not set" and falls
back to `$GOPATH/bin`, then `$HOME/go/bin` without a go toolchain
(measured with a go-less PATH).

### 2026-10-09 Config file precedence bug (env > config > default)
`config` was dead weight: `config_load()` sourced it and then unconditionally
overwrote all five settings with the built-in defaults, so `LOG_DIR`,
`SKIP_CHANNELS`, `GO_BIN_DIR`, `LOG_KEEP` and `STATUS_AUR` from the file never
took effect (`STATUS_AUR=1` never enabled the AUR check, `SKIP_CHANNELS` never
skipped). Each setting now resolves `SYSUPDATE_*` → config value → default.
Measured: `LOG_KEEP=7`, `SKIP_CHANNELS="npm code"`, `STATUS_AUR=1` from a
config file are all honored, and an env var still wins over the file.

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