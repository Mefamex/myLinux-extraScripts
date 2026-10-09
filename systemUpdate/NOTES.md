# NOTES

### The config file is tracked on purpose
`config` is committed so a fresh clone runs correctly as-is and a reviewer can
see what ships. There is no `config.template`. The script also runs fine if
`config` is deleted — every setting has a built-in default.

Precedence is uniform: `SYSUPDATE_*` environment variable > `config` file >
built-in default.

Fixed 2026-10-09: `config_load()` used to source the file and then
unconditionally overwrite every value with the default, so the file was dead
weight (`STATUS_AUR=1` in `config` never enabled the AUR check). Each setting
now resolves `SYSUPDATE_*` → config value → default. See TODO.DONE.md.

### Where each setting is read
`LOG_DIR`, `LOG_KEEP` → `lib/log.sh`; `SKIP_CHANNELS`, `GO_BIN_DIR` →
`lib/apps.sh` (runner); `STATUS_AUR` → `lib/status.sh`.

### LOG_DIR cascade (like systemReport)
When `LOG_DIR` is empty (the default), the log directory is resolved
automatically using the first writable candidate (see `resolve_log_dir()` in
`lib/log.sh`):

1. `xdg-user-dir DOCUMENTS` → `$candidate/systemUpdate` (e.g. `~/Belgeler/systemUpdate`)
2. English names → `~/Documents/systemUpdate`, `~/Document/systemUpdate`
3. Home backup → `~/systemUpdate`
4. XDG state dir → `${XDG_STATE_HOME:-$HOME/.local/state}/systemUpdate`

To force a specific directory, set `LOG_DIR` in `config` or
`SYSUPDATE_LOG_DIR=/path` in the environment.

### Why there is no line cap on reports
See "Reports are never truncated" in README.md.

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

### GO_BIN_DIR must never collapse to an empty string
`go env GOBIN` prints an EMPTY line with rc=0 when GOBIN is unset, so a `||`
fallback after it never fires. If GO_BIN_DIR were "", the go channel would
report "not installed" despite installed tools (`_ch_go_available` tests
`-d "$GO_BIN_DIR"`). `config_load()` now treats an empty `go env` result as
"not set" and derives `$GOPATH/bin`, then falls back to `$HOME/go/bin` without
a go toolchain. Fixed 2026-10-09.

### SIGPIPE: piping the script's output is safe
`./systemUpdate.sh --status | head` used to kill the script: tee died of
SIGPIPE, which killed bash before the EXIT trap ran — leaving a temp FIFO dir
in `/tmp` and a log file without its footer (measured 2026-10-09).
`systemUpdate.sh` ignores SIGPIPE (`trap '' PIPE`) so a closed consumer is a
plain write error instead of a death, and `_run_tty()` stops reopening the
FIFO once its reader (tee) is gone. Verified: `.. | head -3` completes with
rc=0, a complete log file, and no leftover temp dir.

### Composer channel requires a global composer.json
`composer global show -N` fails (rc=1, "could not find composer.json") when
composer exists but no global packages were ever installed. The channel counts
as absent unless composer AND a global composer.json exist. Home resolution
mirrors composer itself: `COMPOSER_HOME` → `~/.composer` (legacy) →
`$XDG_CONFIG_HOME|~/.config/composer`. Fixed 2026-10-09.

### Section spacing
Each section header prints three blank lines after the header block
(`section()` adds `\n\n\n`). Confirmed against the real log, where
`[3/5] Firmware` and `[4/5] DKMS` were too close before.

### Channel numbering
App channels are numbered `[i/total]`, e.g. `[1/16] npm — NPM global packages`.
The total is computed from the channel table, so adding a channel updates it
automatically.