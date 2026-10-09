# TODO

## To do

### Optional: real diffs for the other inventory channels
`pipx`, `uv`, `cargo`, `dotnet`, `flatpak` and `composer` still print *what is
installed* rather than *what would change*. Their lists are short (0–3 lines)
so the problem never became visible, but it is the same bug the VS Code channel
had. `pipx` and `uv` have no dry-run flag (verified), so a real diff may not be
available for them without going to their registries the way VS Code does.

### Show download progress in terminal during updates
Make pacman/yay download progress (bytes downloaded, speed, ETA, per-package
progress) visible in real time on terminal while also being logged.

## Bugs found in review (2026-10-09)

Record of the review findings. Everything fixed is documented in the
"2026-10-09" section of TODO.DONE.md; still-open items are marked **[OPEN]**.

- [FIXED] `config` file was completely ignored (precedence was env > default).
- [FIXED] `GO_BIN_DIR` collapsed to "" when `go env GOBIN` prints empty.
- [FIXED] SIGPIPE on `.. | head` / early `less` quit killed the script, leaked
  `/tmp/.systemUpdate-tee-*` and truncated the log.
- [FIXED] `confirm` prompt advertised `a`/`A`/`q` in the system scope
  (firmware), where they were silently treated as "no".
- [FIXED] Deferred channels ran their report twice.
- [FIXED] Runner reused a previous channel's `CHANNEL_*` when a file forgot
  one; a missing `CHANNEL_UPDATE` could silently run the wrong update command.
- [FIXED] Unknown-ID check in sort.conf used regex matching (`pip` matched
  `pipx`).
- [FIXED] Doc drift: README/NOTES claims that were never true (`.gitignore`
  listed but absent, "every line commented out", cascade step that was never
  implemented, header comment said "same minute").
- [FIXED] composer channel: `composer global show -N` failed loudly (rc=1,
  "could not find composer.json") when composer exists but no global packages
  were installed. CHANNEL_PRESENT now requires composer AND a global
  composer.json, so the channel reports "not installed" (2026-10-09).
- [OPEN] Report-only channels (`cargo`, `docker`, `flatpak`, `dotnet`) print
  the inventory, not a diff — same class of issue the VS Code channel had (see
  "Optional: real diffs" above).

## Re-check / Verify

### Verify `_run_tty` FIFO approach under load
- Run multiple concurrent updates (parallel terminals) → ensure no FIFO collision
- Test with large output (pacman -Syu with many packages) → ensure tee doesn't block
- SIGINT during update → ✅ verified 2026-10-09 (rc=130, footer written, FIFO
  dir removed — see TODO.DONE.md)

### Validate `sort.conf` edge cases
All verified 2026-10-09 on a throwaway copy of the tool (see TODO.DONE.md):
- Duplicate IDs → first wins, warn on later ✅
- Unknown IDs → warn, continue (exact match) ✅
- Missing `sort.conf` → warn + alphabetic fallback ✅
- Empty lines / comments → ignored ✅
(While verifying: the redundant runner init was removed, which had been
printing every warning twice.)

### Test `--full` flag end-to-end
- `--full --system` → skip confirmations, pacman/yay still prompt [Y/n]
- `--full --apps` → skip confirmations, all channels auto-yes
- `--full` (both) → full non-interactive except sudo/pacman prompts
- Verify log captures all output correctly

### Channel-specific verification
- **go channel**: private repo handling (404 → skip gracefully)
- **code channel**: marketplace API rate limits / timeouts
- **docker channel**: daemon not running → "not installed" correctly
- **flatpak/dotnet/cargo**: report-only, no update command

## Research / Improve

### Real diffs for report-only channels (optional)
| Channel | Registry API | Dry-run support | Approach |
|---------|--------------|-----------------|----------|
| cargo   | crates.io    | `--dry-run` (unstable) | Use `cargo install --list --dry-run` |
| composer| Packagist    | `--dry-run` ✅ | Use `composer global update --dry-run` |
| pipx    | PyPI         | ❌ | Query PyPI JSON API per package |
| uv      | PyPI         | ❌ | Query PyPI JSON API per package |
| flatpak | Flathub      | ❌ | Query Flathub API (ostree) |
| dotnet  | NuGet        | ❌ | Query NuGet API per package |

### Parallel channel execution (optional)
- Run independent channels in parallel (npm, pipx, uv, etc.)
- Need to coordinate `_run_tty` FIFO access (serialization or per-channel FIFO)
- Complex: `_run_tty` uses shared FIFO/tee → would need redesign

### Config validation
- Add `config_validate` function to check config file syntax on load
- Warn on deprecated/unknown settings
- Document all `SYSUPDATE_*` env vars in one place

### Log improvements
- Add `--log-dir` CLI flag to override log directory (currently only env/config)
- Add `--log-keep` CLI flag to override retention
- Structured log format option (JSON lines) for tooling

### Performance
- VS Code channel: cache marketplace responses (TTL: 1h) to avoid repeated API calls
- Go channel: parallel `go install` for multiple tools
- System update: `pacman -Sy` once at start (already done via yay)

### Error handling
- ~~`_run_tty`: capture command exit code correctly (currently returns 0 on
  pipefail?)~~ → ✅ verified 2026-10-09: rc propagates correctly, including
  pipefail pipelines (`false` → 1, `true | true` → 0, `false | true` → 1).
- Channel update failure: continue vs abort (currently continues, logs warn)
- Network timeouts: VS Code (25s), consider making configurable

### UX improvements
- Progress indicator for long-running channels (code, go, npm)
- Summary at end: show which channels had updates vs skipped vs failed
- `--dry-run` flag for entire tool: show what *would* run without executing

## Nice to have

### Add new channels
- `mise` / `asdf` / `rtx` — version manager tools
- `bun` — `bun upgrade`
- `deno` — `deno upgrade`
- `rustup` — `rustup update` (system tool, but manages toolchains)
- `snap` — `snap refresh` (if installed)

### Shell completions
- Generate bash/zsh/fish completions for `systemUpdate.sh`
- Flag: `--generate-completion <shell>`

### Health check
- `systemUpdate.sh --doctor` → verify all dependencies (yay, sudo, fwupdmgr, dkms, checkupdates, curl, jq)
- Report missing optional tools per channel

### Man page
- Generate `systemUpdate.1` from README / help text
- Install via `make install` or package