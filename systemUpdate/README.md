# systemUpdate

A simple, clear way to update Arch Linux and the tools pacman does not own.

The goal is one sentence: **small parts, each part asks for confirmation,
every run is logged**.

## Installation

The script installs nothing and runs from wherever you keep it. The only thing
worth knowing in advance: `curl` and `jq` (both in Arch's `extra` repository, not
`base`) make the VS Code channel show a real list of outdated extensions instead
of listing everything you have. Without them the script still works — that one
channel just says it could not check.

```bash
git clone https://github.com/Mefamex/myLinux-extraScripts.git
cd myLinux-extraScripts/systemUpdate
./systemUpdate.sh --status    # read-only: see what is pending first
```

If you prefer, copy just this directory somewhere else — it is
self-contained and never reads anything outside it.

Settings live in `config`, which IS tracked in git: every line in it is
commented out, so a fresh clone runs correctly as-is and you can see exactly
which values ship. Uncomment a line to change a value, or pass an environment
variable for a change that is yours alone. The script also runs fine if
`config` is deleted — every setting has a built-in default.

### What it expects to be installed

The system step uses whatever you already have; nothing is installed for you.

| Command | Used for | If missing |
|---|---|---|
| `yay` | system + AUR updates | step 2 stops with an error |
| `sudo` | keyring and package updates | asks for your password |
| `pacman` | keyring, kernel detection | always present on Arch |
| `fwupdmgr` | firmware | step 3 is skipped |
| `dkms` | kernel modules | step 4 is skipped |
| `checkupdates` | the `--status` package report | `--status` says so and skips that part |
| `curl` + `jq` | the VS Code extension report (compares against the marketplace) | that channel lists what is installed instead and says it could not check; everything else still works |

App channels check themselves: a channel whose tool is not installed is
reported as *not installed* and skipped, so a missing `npm` or `uv` never
fails the run.

## Usage

```bash
./systemUpdate.sh            # system + apps (everything)
./systemUpdate.sh --system   # only pacman/AUR/firmware/DKMS/.pacnew
./systemUpdate.sh --apps     # only npm/VS Code/pipx/uv/... channels
./systemUpdate.sh --status  # changes NOTHING, only reports
./systemUpdate.sh --log     # show the most recent log
./systemUpdate.sh --help
```

The full output (stdout **and** stderr) of every run is written to exactly
one file:

```
systemUpdateYYYY-MM-DD-HH-MM.txt
```

If two runs start in the same minute, the second one gets `-1`, the third `-2`
and so on — nothing is ever overwritten. Old logs are pruned automatically
(see `LOG_KEEP` below).

### Where logs go

By default, the script does **not** hardcode a path. Instead, it resolves a
log directory via a cascade, using the first one that exists and is writable:

1. **Your localized Documents folder** — via `xdg-user-dir DOCUMENTS`. On a
   Turkish system this is `~/Belgeler/systemUpdate`; on English `~/Documents/systemUpdate`.
2. **XDG user-dirs config** — `~/.config/user-dirs.dirs` → `XDG_DOCUMENTS_DIR`.
3. **English fallback** — `~/Documents/systemUpdate` or `~/Document/systemUpdate`.
4. **Home backup (not hidden)** — `~/systemUpdate`. Easy to find without
   guessing.
5. **XDG state dir (last resort)** — `~/.local/state/systemUpdate`.

This mirrors `systemReport`'s approach and means logs land somewhere visible
and expected on every machine, regardless of locale.

To pin a specific directory, set `LOG_DIR` in `config` or pass
`SYSUPDATE_LOG_DIR=/your/path` in the environment.

## System update (5 steps)

The order is intentional:

1. **archlinux-keyring** — signing keys. Without this, new packages often
   fail to verify.
2. **System + AUR** (`yay -Syu`) — both in a single pass.
3. **Firmware** (`fwupdmgr`) — near the end because it can bump the kernel.
4. **DKMS** — a kernel upgrade breaks DKMS modules (nvidia, tuxedo); if they
   are not rebuilt, the next boot can fail to load them.
5. **`.pacnew` / `.pacsave`** — listed only, NEVER deleted.

## App channels

App channels live in a single table inside `lib/apps.sh`. Each one is numbered
(e.g. `1/16`) so you can see exactly how far the run has gone.

| Channel | What it does |
|---|---|
| `npm` | `npm -g update` |
| `code` | `code --update-extensions` |
| `pipx` | `pipx upgrade-all` |
| `uv` | `uv tool upgrade --all` |
| `opencode` | `opencode upgrade` |
| `claude` | `claude update` |
| `codex` | `codex update` |
| `pnpm` | `pnpm self-update` |
| `pip` | `pip install --user -U <packages>` (with `--break-system-packages`) |
| `go` | `go install <module>@latest` per tool |
| `composer` | `composer global update` |
| `gh` | `gh extension upgrade --all` |

Report-only channels (they print a list and never run an update): `cargo`,
`docker`, `flatpak`, `dotnet`.

## Safety rules

These are deliberate choices:

- **Every channel asks for confirmation, default is NO.** If stdin is not a
  terminal (cron, a script, a pipe) confirmations are automatically skipped as
  NO. Something that gets silently skipped is only work lost; something that
  runs by accident cannot be undone.
- **`brew` is excluded on purpose.** `/opt/brew` belongs to pacman and running
  `brew update` would do `git pull` on it (high risk of conflict). There are 27
  formulae installed, but `/opt/brew/bin` is not on `PATH` anyway, so none of
  them are reachable.
- **Nothing is ever deleted.** No `docker system prune`, no `brew cleanup`.
  `.pacnew` files are only listed — they are your `/etc` settings, and
  automatic deletion would be irreversible.
- **Kernel detection uses ownership, not a name pattern.** Matching `^linux`
  also caught `linux-headers`, `linux-api-headers`, `linux-wifi-hotspot` and 14
  `linux-firmware-*` packages. Updating one of those would incorrectly warn
  about a reboot. The script now only treats packages as the *real* kernel if
  they install under `/usr/lib/modules/<version>/kernel/` (measured: `linux`
  installed files there, `linux-headers` did not).
- **Output is locale-independent.** Tools like `pacman -Qo` translate their
  output (`paketine ait` vs `is owned by`), so we never parse localized text.
  We only use commands that return raw package names/versions (`pacman -Qqo`,
  `pacman -Q`).

## Files

| File | Purpose |
|---|---|
| `systemUpdate.sh` | Entry point: arguments, signal trap, log orchestration |
| `config` | The settings. Tracked in git, every line commented out |
| `lib/config.sh` | Loads settings from the config file or environment |
| `lib/log.sh` | FIFO+tee logging, confirmations, reporting, log pruning |
| `lib/system.sh` | The 5-step system update + reboot detection |
| `lib/status.sh` | `--status` read-only reporting |
| `lib/apps.sh` | The channel table + per-channel helpers |
| `README.md` | This file |
| `TODO.md` | Open work, notes on how things work, and why they are the way they are |
| `.gitignore` | Only the temporary logging FIFOs (`config` is deliberately tracked) |

## Settings

Settings come from the `config` file or the environment. The environment
overrides the file.

| Setting | Env var | Default | Notes |
|---|---|---|---|
| `LOG_DIR` | `SYSUPDATE_LOG_DIR` | *cascade* | Where log files go (see cascade below) |
| `SKIP_CHANNELS` | `SYSUPDATE_SKIP_CHANNELS` | empty | Space-separated channel IDs to skip, e.g. `npm go` |
| `GO_BIN_DIR` | `SYSUPDATE_GO_BIN_DIR` | `$HOME/go/bin` | Where `go install` places binaries |
| `LOG_KEEP` | `SYSUPDATE_LOG_KEEP` | `50` | How many log files to keep |
| `STATUS_AUR` | `SYSUPDATE_STATUS_AUR` | `0` | If `1`, `--status` also queries the AUR (`yay -Qua`) — this does a network request and is not instant |

### LOG_DIR cascade

When `LOG_DIR` is empty (the default), the log directory is resolved
automatically using the first writable candidate:

1. `xdg-user-dir DOCUMENTS` → `$candidate/systemUpdate` (e.g. `~/Belgeler/systemUpdate`)
2. `~/.config/user-dirs.dirs` → `$XDG_DOCUMENTS_DIR/systemUpdate`
3. English names → `~/Documents/systemUpdate`, `~/Document/systemUpdate`
4. Home backup → `~/systemUpdate`
5. XDG state dir → `${XDG_STATE_HOME:-$HOME/.local/state}/systemUpdate`

To force a specific directory, set `LOG_DIR` in `config` or
`SYSUPDATE_LOG_DIR=/path` in the environment.

## Reports are never truncated

Every channel prints *what would change*, in full, with no line cap. Here is
the real head of the VS Code report on this machine — the first 3 of 26, then
the closing count:

```
  [2/16] code — VS Code extensions
      eamodio.gitlens                              19.2.0 -> 2026.10.10518
      ms-python.debugpy                    2026.7.12731008 -> 2026.7.12731012
      ms-vscode.cmake-tools                           1.24.42 -> 1.25.0
      ... (23 more extension lines follow) ...
      26 of 164 extensions have a newer version
```

There is no cut-off line like `... (161 more lines)`. The final line is a count
of what was printed above it, not a replacement for it.

There used to be a `MAX_REPORT_LINES` setting that cut these lists at 12 lines.
It existed for one channel only — VS Code — and it was hiding a wrong report
rather than a long one: that channel printed `code --list-extensions`, which is
the list of everything you *have*, not the list of what would change. 164 lines,
of which most said "already installed". The channel now compares your installed
versions against the marketplace and prints only the ones that are behind.

A note on that comparison, since it is the one channel that touches the network:
the `code` CLI has no "list outdated" flag, so the script queries the public
marketplace API directly (`curl` + `jq`, both from the `extra` repository, not
`base`). If either is missing, or the API does not answer, the channel says so
and falls back to listing what is installed — it never reports "nothing to
update" when it did not actually check. Measured cost: 164 extensions in about
3 seconds, sent in batches of 100.

## FAQ / troubleshooting

**It asks for sudo a few times.**
Yes. `--system` step 1 (`archlinux-keyring`) and step 2 (`yay -Syu`) use
`sudo`. That is expected.

**`--status` says "official repositories are current — the AUR is NOT included".**
`checkupdates` only looks at official repositories by design. To also query
the AUR in `--status`, set `STATUS_AUR=1` in the config (or
`SYSUPDATE_STATUS_AUR=1`). Doing so runs a network operation and can take a
second or two.

**It says "could not determine the reboot status" but a kernel just updated.**
When that happens the baseline could not be read. To check by hand, use the
same locale-independent form the script uses:

```bash
pacman -Qqo /usr/lib/modules   # raw package names: linux, linux-headers, ...
```

`linux` appearing there means the kernel package is present. Avoid `pacman -Qo`
for this: its output is translated ("paketine ait" / "is owned by"), which is
why the script never parses it.

**`pip` uses `--break-system-packages`. Is that safe?**
Arch ships `/usr/lib/python3.x/EXTERNALLY-MANAGED` (PEP 668). Without this
flag, `pip install --user` is refused (`error: externally-managed-environment`).
Because it uses `--user` it writes only under `~/.local` and never touches the
system site-packages. The cleaner long-term alternatives (`pipx`, `uv`) are
separate channels already. This channel is only there for tools that were
installed with plain `pip`.

**Logs keep piling up.**
They are pruned automatically to the newest `LOG_KEEP` files. The default is
`50`. You can increase or decrease it in the config. The pruning only ever
removes our own log files — never anything else.

**The log file shows "[3/5] Firmware" and "[4/5] DKMS" with big gaps.**
That is intentional: each section prints three extra blank lines after its
header to make the log much easier to skim. The formatting is deliberate, not
a bug.
