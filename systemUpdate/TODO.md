# TODO

## To do

### Commit systemUpdate
The 10 files are **staged** and complete. Run `git status` to verify, then commit.
The root README also references `systemReport`, which is a separate project.

### Run one real update
Every test so far is read-only (`--status`, or `--apps` with stdin closed). No
channel has actually performed an update yet. Worth doing once on a safe
single-package channel (`pnpm` or `opencode`) to prove the confirm → update →
log path works end to end.

### Check the ~/.zshrc pointer
Section 10 of `~/.zshrc` points at this tool. It was written for the old
`guncelle` name, so confirm the path and the wording still match. `zsh -n
~/.zshrc` should stay clean.

### Remove the stale log directory
`~/.local/state/updater/` is left over from the pre-rename tool. Safe to delete;
nothing reads it.

### Optional: real diffs for the other inventory channels
`pipx`, `uv`, `cargo`, `dotnet`, `flatpak` and `composer` still print *what is
installed* rather than *what would change*. Their lists are short (0–3 lines)
so the problem never became visible, but it is the same bug the VS Code channel
had. `pipx` and `uv` have no dry-run flag (verified), so a real diff may not be
available for them without going to their registries the way VS Code does.

## Notes

### The config file is tracked on purpose
`config` is committed and every setting in it is commented out, so a fresh clone
runs correctly as-is and a reviewer can see what ships. There is no
`config.template`. `.gitignore` only covers the temporary logging FIFOs.
The script also runs fine if `config` is deleted — every setting has a default.

### Where each setting is read
`LOG_DIR`, `LOG_KEEP` → `lib/log.sh`; `SKIP_CHANNELS`, `GO_BIN_DIR` →
`lib/apps.sh`; `STATUS_AUR` → `lib/status.sh`. Precedence is uniform:
environment > config file > built-in default.

### LOG_DIR cascade (like systemReport)
When `LOG_DIR` is empty (the default), the log directory is resolved
automatically using the first writable candidate:

1. `xdg-user-dir DOCUMENTS` → `$candidate/systemUpdate` (e.g. `~/Belgeler/systemUpdate`)
2. `~/.config/user-dirs.dirs` → `$XDG_DOCUMENTS_DIR/systemUpdate`
3. English names → `~/Documents/systemUpdate`, `~/Document/systemUpdate`
4. Home backup → `~/systemUpdate`
5. XDG state dir → `${XDG_STATE_HOME:-$HOME/.local/state}/systemUpdate`

To force a specific directory, set `LOG_DIR` in `config` or
`SYSUPDATE_LOG_DIR=/path` in the environment.

### Why there is no line cap on reports
See "Reports are never truncated" below.

### pip --break-system-packages
Required for Arch Python (PEP 668). Without it `pip install --user` fails with
`error: externally-managed-environment`. With `--user` it only writes to
`~/.local` and never touches system site-packages. `pipx` and `uv` are the
cleaner alternatives and are already separate channels; this one exists for
tools installed with plain `pip` (e.g. `git-filter-repo`).

### DKMS output filtering
Warn if any line does not contain `installed`. `added` is expected during a
rebuild (not an error). `failed`/`error` also trigger the warning, which is
correct. If false positives appear, use a more selective filter.

### go install <path>@latest and local replaces
The Go channel reads the embedded module path from each binary (`go version -m`)
and runs `go install <path>@latest` for public repositories. Binaries with no
embedded module info are skipped (often locally built, showing `(devel)`). Paths
without a domain are skipped — those are local projects and `@latest` cannot
resolve them.

### Section spacing
Each section header prints three blank lines after the header block
(`section()` adds `\n\n\n`). Confirmed against the real log, where
`[3/5] Firmware` and `[4/5] DKMS` were too close before.

### Channel numbering
App channels are numbered `[i/total]`, e.g. `[1/16] npm — NPM global packages`.
The total is computed from the channel table, so adding a channel updates it
automatically.

## Done

### Rename to `systemUpdate`, all English
`guncelle/` → `systemUpdate/`; `systemUpdate.sh`; `SYSUPDATE_` environment
prefix. Code, comments, `--help`, file names, variable names and docs are all
English.

### Reports are never truncated (`MAX_REPORT_LINES` removed)
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

### Batch concatenation bug (found while adding the above)
`latest+=$(...)` strips the trailing newline, so with more than one batch the
last line of batch 1 ran into the first line of batch 2. Measured corruption:
`1.4.0ms-vscode.cpptools` — a version glued to the next extension's id. Fixed
with an explicit `$'\n'`.

### Log retention
`log_close()` prunes to the newest `LOG_KEEP` files (default 50). This is the
only place the tool deletes anything, and only ever its own log files (matching
`<label>*.txt`). A non-numeric `LOG_KEEP` is treated as "keep everything", so a
typo can never delete logs.

### `--status` and the AUR
`checkupdates` queries official repositories only, so AUR is opt-in via
`STATUS_AUR=1` (`yay -Qua`). AUR queries are network operations and can be slow;
making them opt-in preserves `--status` as a quick glance. Note `yay -Qua`
cannot report orphaned AUR packages either way.

### trap exit after SIGINT
Without an explicit `exit`, the INT trap let the script continue and exit rc=0
while the user believed it was cancelled. Fixed: `trap -` first, then
`log_close`, then `exit $sig`.

### Kernel detection (false positives)
The old `grep -E '^linux' | grep -v '^linux-firmware'` matched `linux-headers`,
`linux-api-headers` and `linux-wifi-hotspot`. Only packages that install under
`/usr/lib/modules/<version>/kernel/` are treated as the real kernel (measured:
`linux` matches, `linux-headers` installs only `build/` and matches 0).
Candidates come from `pacman -Qqo` (raw names) and the version from `pacman -Q`,
both locale-independent. Parsing the translated `pacman -Qo` output was removed
entirely.

### Parallel log name collisions
`[ -e "$f" ]` races under parallel starts (measured: 3 runs → 1 file). Fixed with
atomic reservation via `set -o noclobber`; 5 parallel runs then produced 5 files.

### FIFO left behind on SIGINT
`wait` hangs if a child still holds the FIFO open. Fixed by unlinking the FIFO
*before* waiting — `rm` removes the path without affecting open descriptors, and
`tee` then reaches EOF.

### Smaller fixes
`code --update-extensions` exists (confirmed in `code --help`), so the VS Code
channel needs no manual loop. `uv tool upgrade --all` is used. The `--status`
message was corrected to say the AUR is *not* included instead of claiming
everything is current.
