# NOTES

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