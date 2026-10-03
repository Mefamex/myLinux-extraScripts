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

## Re-check / Verify

### Verify `_run_tty` FIFO approach under load
- Run multiple concurrent updates (parallel terminals) → ensure no FIFO collision
- Test with large output (pacman -Syu with many packages) → ensure tee doesn't block
- Test SIGINT during update → verify trap cleanup works (FIFO unlink + tee wait)

### Validate `sort.conf` edge cases
- Duplicate IDs → first wins, warn on later (implemented, verify)
- Unknown IDs → warn, continue (implemented, verify)
- Missing `sort.conf` → warn + alphabetic fallback (implemented, verify)
- Empty lines / comments → ignored (implemented, verify)

### Test `--full` flag end-to-end
- `--full --system` → skip confirmations, pacman/yay still prompt [Y/n]
- `--full --apps` → skip confirmations, all channels auto-yes
- `--full` (both) → full non-interactive except sudo/pacman prompts
- Verify log captures all output correctly

### Channel-specific verification
- **go channel**: private repo handling (404 → skip gracefully)
- **code channel**: marketplace API rate limits / timeouts
- **composer channel**: fails cleanly when no composer.json
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
- `_run_tty`: capture command exit code correctly (currently returns 0 on pipefail?)
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