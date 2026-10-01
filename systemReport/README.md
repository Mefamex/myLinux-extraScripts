# systemReport

Arch Linux system report collector — modular, readable, careful.

> |                  |                          |
> | ---------------- | ------------------------ |
> | *author*         | **@mefamex**             |
> | *version*        | 5.0.2                    |
> | *version date*   | 2026-10-01               |
> | *platform*       | Arch Linux (x86_64)      |


## Purpose

`systemReport` collects hardware, network, package, log and configuration state
in one place. Each section is written to its own file, everything is merged into
`arch_full_report.txt`, and every line printed to the terminal is saved to
`terminal_log.txt` without colour codes.

How it is put together: one file per section under `lib/sections/`, version
information in a **single source of truth** (`VERSION`), the report directory
resolved from XDG rules with a home-directory backup, old reports pruned with a
"keep the last N" rule instead of being deleted wholesale, and the terminal log
written inside each report folder so a folder is a self-contained artefact.

## Features

- **Modular**: every section is an independent file, the main script stays
  readable, maintenance is cheap.
- **Version system**: `VERSION` is the only place a version number exists. It
  is printed in the banner, in `--version`, in every section header, in the
  combined report and at the start of the terminal log.
- **Automatic output root**: `xdg-user-dir DOCUMENTS` → `XDG_DOCUMENTS_DIR` →
  `~/Documents` → `~/systemReport` (home backup) → `~/.local/share/systemReport`.
  No localised name such as "Belgeler" is hardcoded anywhere.
- **One-time sudo**: `sudo -v` asks for the password once, every later privileged
  check goes through without prompting.
- **Terminal log**: the complete console output is written to `terminal_log.txt`
  with ANSI codes stripped, so it is greppable and pasteable.
- **Section filter**: `--only 03,04,05` collects only the sections you name.
- **Gentle cleanup**: old reports are deleted without asking, but the newest N
  are kept (default 10).
- **Safe**: runs under `set -uo pipefail`, refuses to start when a module is
  missing, and reports an invalid `--only` number as an error instead of quietly
  collecting nothing.
- **Readable output**: boundaries are two or three lines tall, so the shape of a
  run is legible while it scrolls.
- **ShellCheck clean**: every `.sh` file passes `shellcheck -x`.

## Verification status

Tested on a real Arch machine on 2026-10-01: every flag, every environment
variable, invalid input and its exit code, all ten sections one by one and in a
full run, cleanup with fake old report folders, and the same-second collision
path. `bash -n` and `shellcheck -x` are clean on all 18 shell files.

Two paths are not proven yet and are listed in `todo.md`: a failed `sudo`
validation (a genuinely wrong password), and reading an alternate config file
through `SR_CONFIG`.

## Usage

```bash
# Full report
./systemReport.sh

# Only selected sections
./systemReport.sh --only 03,04

# Choose the report root
./systemReport.sh -o /tmp/report-test

# Skip checks that need root
./systemReport.sh --nosudo

# Do not touch old reports
./systemReport.sh --noclean

# How many reports to keep (default 10)
./systemReport.sh --keep 20

# Version and its date
./systemReport.sh --version

# Help (printed from the script's own header)
./systemReport.sh --help
```

## Settings

Settings live in `config` next to the script. That file **is tracked in the
repository on purpose**: the defaults live there, so a fresh clone runs
immediately and a reviewer can see the shipped settings. There is no template
file and no git-ignored personal copy.

| Setting           | Meaning                                           | Default    |
| ----------------- | ------------------------------------------------- | ---------- |
| `REPORT_ROOT`     | Parent directory for report folders, empty = auto | auto       |
| `KEEP_REPORTS`    | How many reports to keep                          | 10         |
| `USE_SUDO_CHECKS` | `1/0` — run the checks that need root             | 1          |
| `CLEANUP_ENABLED` | `1/0` — delete reports beyond `KEEP_REPORTS`      | 1          |
| `LOG_FILE`        | Terminal log path; empty = inside each report     | per-report |

`config` is sourced by the shell, so `~` inside a quoted value is **not**
expanded. Write `"$HOME/systemReport"`, not `"~/systemReport"` — the latter
becomes `$HOME/~/systemReport`. As a command-line argument `-o ~/x` works fine,
because the calling shell expands it before the script sees it.

Every setting can also be given as an environment variable, which overrides the
config file. Command-line arguments override both.

## Terminal log

Every line printed to the terminal is also written to `terminal_log.txt`
**inside the report folder**, with ANSI colour codes stripped. That is the
shipped behaviour (`LOG_FILE` is empty in `config`), and it is deliberate: every
report carries its own complete terminal output, so a folder can be zipped and
handed over as a unit with nothing from another run mixed in.

The log header carries the version, the author, the host and the start time:

```text
systemReport 5.0.2 (2026-10-01) - terminal log
Author   : @mefamex
Host     : archMfmx
Started  : 2026-10-01 20:00:10
```

The log is the artefact most likely to be pasted straight into a chat message,
which is why the version is in the header rather than only in the report files.

Set `LOG_FILE` to a fixed path for the other behaviour: one shared file that
accumulates every run, with runs separated by a blank line and a rule. The
script creates the directory if it does not exist, and reports a failure to
write instead of swallowing it.

| Variable         | Meaning                        |
| ---------------- | ------------------------------ |
| `SR_REPORT_ROOT` | Report root (parent directory) |
| `SR_KEEP`        | Reports to keep                |
| `SR_SUDO`        | `0` skips root-only checks     |
| `SR_CLEANUP`     | `0` leaves old reports alone   |
| `SR_LOG`         | Terminal log path              |
| `SR_CONFIG`      | Use a different config file    |

Precedence, strongest first: **argument → environment variable → config file**.

## Output root resolution

When `REPORT_ROOT` is empty the script tries these in order and prints the one it
used:

1. `xdg-user-dir DOCUMENTS` — honours the localised Documents folder
2. `XDG_DOCUMENTS_DIR` from `~/.config/user-dirs.dirs`
3. `~/Documents`, `~/Document` — plain English names
4. `~/systemReport` — backup inside your home directory, not hidden
5. `~/.local/share/systemReport` — last resort, exists on every account

A missing Documents folder is a normal condition, not an error: minimal
installs, containers and fresh accounts all lack one. The chain always ends
inside the home directory, so there is no state in which the script has nowhere
to write.

## Structure

```text
systemReport/
├── systemReport.sh           # entry point
├── VERSION                   # single source of truth (VERSION, VERSION_DATE, AUTHOR)
├── config                    # settings, tracked in the repository
├── README.md
├── todo.md                   # working notes: done, open, decisions
└── lib/
    ├── version.sh            # version reading + banner
    ├── config.sh             # settings loading (env + config file)
    ├── output.sh             # output root resolution
    ├── log.sh                # console + log file dual writing, rules
    ├── sudo.sh               # one-time sudo validation
    ├── report.sh             # section writing + merge
    ├── cleanup.sh            # keep the last N reports
    └── sections/
        ├── 00_privacy.sh     01_system.sh      02_hardware.sh
        ├── 03_storage.sh     04_graphics.sh    05_network.sh
        ├── 06_packages.sh    07_logs.sh        08_configuration.sh
        └── 09_users.sh
```

## Sections

| No  | File                   | Contents                                                             |
| --- | ---------------------- | -------------------------------------------------------------------- |
| 00  | `00_privacy.txt`       | Privacy notice (read before sharing)                                 |
| 01  | `01_system.txt`        | Kernel, distribution, boot time, session                             |
| 02  | `02_hardware.txt`      | CPU, RAM (dmidecode), PCI/USB, temperatures, battery                 |
| 03  | `03_storage.txt`       | Disks, df, inodes, fdisk, SMART                                      |
| 04  | `04_graphics.txt`      | GPU, displays (Wayland/X11), DRM/KMS, OpenGL                         |
| 05  | `05_network.txt`       | IP, routes, DNS, ports, NetworkManager (**sensitive**)               |
| 06  | `06_packages.txt`      | pacman (explicit/AUR), flatpak, pipx, modules                        |
| 07  | `07_logs.txt`          | dmesg, journalctl, failed services                                   |
| 08  | `08_configuration.txt` | fstab, pacman.conf, mkinitcpio, grub, modprobe, udev (**sensitive**) |
| 09  | `09_users.txt`         | Accounts, groups, recent logins, auth logs                           |

## Report folder contents

```text
~/Documents/systemReport/arch_report_20261001_192758/
├── 00_privacy.txt          # section files
├── 01_system.txt
├── ...
├── arch_full_report.txt    # everything merged + table of contents
└── terminal_log.txt        # version, author, host and kernel appear first
```

## Version history

- **5.0.2** (2026-10-01) — First full round of machine testing. Fixed: a stray trailing comma in the `--only` echo line, the same-timestamp warning printed before the path block instead of after it, and the `~`-in-`config` path pitfall now documented.
- **5.0.1** (2026-10-01) — Terminal log written inside each report again, with version and author in its header. Log directory created automatically. A shared fixed-path log is still available by setting `LOG_FILE`.
- **5.0.0** (2026-10-01) — Full English rewrite. Settings, code and output are English only. The template file is gone — `config` is tracked directly. Output root falls back to a home-directory backup. Rules are 2–3 lines tall. Keep count default 10. Author credit added.
- **4.0.0** (2026-10-01) — Full modular rewrite. XDG-aware output root, terminal log added, `--only` filter, keep-last-N protection, `VERSION.txt`.
- **3.1** (2026-08-11) — Previous version (single file, `--nosudo`, `--noclean`, old folders deleted without asking).

## Deliberate non-goals

- Colour codes are never written to `terminal_log.txt`, so the log stays
  shareable. `NO_COLOR=1` is honoured as well.
- No personal data is masked or redacted. The report shows the machine as it
  actually is; `00_privacy.txt` tells the reader which files to look at before
  sharing.
- Sections never call each other; each one is independent.
- A missing module stops the script rather than producing a quietly incomplete
  report.
- No network name, device name or personal value is hardcoded in the script.
- Review **05_network.txt** and **08_configuration.txt** before sharing (see
  `00_privacy.txt`).