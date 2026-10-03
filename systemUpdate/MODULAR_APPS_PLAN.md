# Modular App Channels — Implementation Plan

## Current State
- Single `lib/apps.sh` with 16 channels in a heredoc table
- Helper functions for complex channels: `_code_report`, `_code_report_fallback`, `_pip_report`, `_upd_pip`, `_go_available`, `_go_report`, `_go_module`, `_upd_go`
- Main `apps_update()` function handles the flow

## Target Structure
```
lib/
├── apps.sh                    # Thin wrapper → sources lib/apps/runner.sh
└── apps/
    ├── runner.sh              # Main orchestrator: discovers, loads, runs channels
    ├── sort.conf              # Channel sort order (ID per line, see below)
    └── channels/
        ├── npm.sh
        ├── code.sh
        ├── pipx.sh
        ├── uv.sh
        ├── opencode.sh
        ├── claude.sh
        ├── codex.sh
        ├── pnpm.sh
        ├── pip.sh
        ├── go.sh
        ├── cargo.sh
        ├── docker.sh
        ├── flatpak.sh
        ├── dotnet.sh
        ├── composer.sh
        └── gh.sh
```

## sort.conf — Channel Order Configuration

Location: `lib/apps/sort.conf` (same directory as `runner.sh`)

Format: one `CHANNEL_ID` per line, in desired execution order. Lines starting with `#` are comments. Empty lines ignored.

```conf
# SystemUpdate app channel execution order
npm
code
pipx
uv
opencode
claude
codex
pnpm
pip
go
cargo
docker
flatpak
dotnet
composer
gh
```

**Behavior:**
- Channels listed in `sort.conf` → run in that exact order (top to bottom)
- Channels NOT in `sort.conf` → run after, sorted alphabetically by `CHANNEL_ID`
- Missing `sort.conf` → **brief warning**, fall back to alphabetic `CHANNEL_ID` order
- Duplicate IDs in `sort.conf` → first occurrence wins, later ignored (with warning)
- Unknown IDs in `sort.conf` → ignored (with warning)

This keeps the config simple and explicit while being backward-compatible.

Each `channels/*.sh` must define these **variables** (sourced by runner):

```bash
# Required
CHANNEL_ID="npm"                    # short, unique, matches SKIP_CHANNELS
CHANNEL_LABEL="NPM global packages" # display name
CHANNEL_PRESENT="command -v npm"    # command to test availability (0=present)
CHANNEL_REPORT="npm outdated -g --depth=0"  # command OR @function_name
CHANNEL_UPDATE="npm -g update"      # command OR @function_name (empty = report-only)
```

**Special values:**
- `CHANNEL_REPORT="@function_name"` → runner calls `function_name` (defined in same file)
- `CHANNEL_UPDATE="@function_name"` → runner calls `function_name` via `_run_tty`
- `CHANNEL_UPDATE=""` → report-only channel (never prompts for update)

**Sort order** is defined in `lib/apps/sort.conf` (not in channel files). Channels not listed run last, alphabetically.

## Runner Responsibilities (`lib/apps/runner.sh`)

1. **Load sort order**: read `lib/apps/sort.conf` (if exists) into array `SORT_ORDER[]`
   - If missing: `warn "sort.conf not found, using alphabetic order"` and continue
2. **Discover channels**: `find lib/apps/channels -name '*.sh'`
3. **Load each**: `source "$channel_file"` → reads variables into arrays
4. **Sort**:
   - First: channels whose `CHANNEL_ID` appears in `SORT_ORDER` (by `SORT_ORDER` index)
   - Then: remaining channels, alphabetically by `CHANNEL_ID`
   - Warn once for duplicate/unknown IDs in `sort.conf`
5. **Run flow** identical to current `apps_update()`:
   - Skip if `SKIP_CHANNELS` contains ID
   - Run `CHANNEL_PRESENT` → if fails, mark "not installed"
   - Print header `[i/total] ID — LABEL`
   - Run `CHANNEL_REPORT` via `report()` (handles `@function`)
   - If `CHANNEL_UPDATE` empty → continue (report-only)
   - Confirm → run `CHANNEL_UPDATE` via `_run_tty` (handles `@function`)
   - Handle defer/update-all/quit logic
5. **Summary**: print updated/absent/skipped counts

## Migration Strategy

### Phase 1: Create structure & runner (no behavior change)
1. Create `lib/apps/channels/` directory
2. Write `lib/apps/runner.sh` with discovery + flow logic
3. Create 16 channel files, copying logic from current `lib/apps.sh`
4. Update `lib/apps.sh` to `source lib/apps/runner.sh` (thin wrapper)
5. Test: `./systemUpdate.sh --status` → identical output

### Phase 2: Verify & clean up
1. Run full update (`./systemUpdate.sh`) → verify all channels work
2. Remove old helper functions from `lib/apps.sh` (now in channel files)
3. Delete old `_channels()` heredoc and `apps_update()` from `lib/apps.sh`
4. `shellcheck` all new files

## Channel File Mapping (Current → New)

| Current ID | New File | Notes |
|------------|----------|-------|
| npm | npm.sh | Simple command |
| code | code.sh | Complex: includes `_VSCODE_*` consts, `_code_report`, `_code_report_fallback` |
| pipx | pipx.sh | Simple command |
| uv | uv.sh | Simple command |
| opencode | opencode.sh | Simple command |
| claude | claude.sh | Simple command |
| codex | codex.sh | Simple command |
| pnpm | pnpm.sh | Simple command |
| pip | pip.sh | Includes `_pip_report`, `_upd_pip` |
| go | go.sh | Includes `_go_available`, `_go_report`, `_go_module`, `_upd_go`, uses `GO_BIN_DIR` |
| cargo | cargo.sh | Report-only (empty UPDATE) |
| docker | docker.sh | Report-only, `CHANNEL_PRESENT="docker info"` |
| flatpak | flatpak.sh | Report-only |
| dotnet | dotnet.sh | Report-only |
| composer | composer.sh | Simple command |
| gh | gh.sh | Simple command |

## Key Implementation Details

### Runner loads channel metadata:
```bash
load_channels() {
    local f
    # 1. Load sort.conf if present
    local sort_file="$_APPS_DIR/sort.conf"
    local -a SORT_ORDER=()
    if [ -f "$sort_file" ]; then
        while IFS= read -r line; do
            line="${line%%#*}"  # strip comments
            line="${line//[[:space:]]/}"  # strip whitespace
            [ -n "$line" ] && SORT_ORDER+=("$line")
        done < "$sort_file"
    else
        warn "sort.conf not found, using alphabetic channel order"
    fi

    # 2. Discover and load channel files
    local -A sort_index=()  # CHANNEL_ID -> position in SORT_ORDER
    local i=0
    for id in "${SORT_ORDER[@]}"; do
        [ -z "${sort_index[$id]:-}" ] && sort_index[$id]=$i
        ((i++))
        # Warn on duplicates
        [ "$i" -gt 1 ] && [ -n "${sort_index[$id]:-}" ] && warn "sort.conf: duplicate ID '$id' (ignored)"
    done

    for f in "$_APPS_DIR/channels"/*.sh; do
        [ -f "$f" ] || continue
        # shellcheck source=/dev/null
        . "$f"
        # Validate required vars
        [ -n "${CHANNEL_ID:-}" ] || { warn "Missing CHANNEL_ID in $f"; continue; }
        # Warn if sort.conf references unknown ID
        [ -n "${sort_index[$CHANNEL_ID]:-}" ] && [ ${#SORT_ORDER[@]} -gt 0 ] || true  # placeholder
        # Store in parallel arrays
        CHANNELS_ID+=("$CHANNEL_ID")
        CHANNELS_LABEL+=("$CHANNEL_LABEL")
        CHANNELS_PRESENT+=("$CHANNEL_PRESENT")
        CHANNELS_REPORT+=("$CHANNEL_REPORT")
        CHANNELS_UPDATE+=("$CHANNEL_UPDATE")
        CHANNELS_SORT+=("${sort_index[$CHANNEL_ID]:-9999}")  # high = after defined ones
    done

    # 3. Sort by CHANNELS_SORT then CHANNEL_ID (decorated sort)
    # ... implementation uses array indices ...
}
```

### Warn on unknown IDs in sort.conf:
```bash
# After loading all channels, check for IDs in sort.conf that don't exist
for id in "${SORT_ORDER[@]}"; do
    [[ " ${CHANNELS_ID[*]} " =~ " $id " ]] || warn "sort.conf: unknown channel ID '$id' (ignored)"
done
```

### Report/Update execution (reuse existing `_run`):
```bash
run_report() { _run "$1"; }   # _run handles @function prefix
run_update() { _run_tty "$1"; }
```

### Preserve existing behavior:
- `SKIP_CHANNELS` from config/env still works
- `GO_BIN_DIR` from config/env still works (passed to go.sh)
- `_run_tty` keeps FIFO fds 3/4 open
- `confirm()` logic (y/N/a/A/q) unchanged
- Deferred channels logic unchanged
- Section header format unchanged
- Summary line unchanged

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Channel file load order | Use `sort.conf` + alphabetic ID tiebreaker for unlisted |
| Missing variable in channel file | Validate on load, warn and skip |
| Function name collisions | Prefix helpers with `_ch_<id>_` (e.g., `_ch_code_report`) |
| `GO_BIN_DIR` not visible in go.sh | Runner exports it before sourcing channel files |
| `report()` / `_run_tty` not available | Runner sources `lib/log.sh` first (already done by apps.sh) |
| Missing `sort.conf` | Brief warning, fallback to alphabetic order (tool still works) |

## Testing Checklist

- [ ] `./systemUpdate.sh --status` → identical channel order, reports, counts
- [ ] `./systemUpdate.sh --apps` → prompts work, updates run, deferred works
- [ ] `./systemUpdate.sh` (full) → system + apps flow works
- [ ] `SKIP_CHANNELS="npm code" ./systemUpdate.sh --status` → skips respected
- [ ] `SYSUPDATE_GO_BIN_DIR=/custom/path ./systemUpdate.sh --status` → go channel uses custom path
- [ ] `shellcheck lib/apps/runner.sh lib/apps/channels/*.sh` → clean
- [ ] `bash -n` on all new files → clean

## Rollback Plan
If issues: `git checkout lib/apps.sh` restores old monolithic version instantly.