# Agent Instructions

## Project Shape

- This repository is a collection of independent Linux tools; there is no shared runtime or build system.
- Keep changes scoped to the tool being changed: `keyboardLeds/`, `systemReport/`, `systemUpdate/`, or `wifisentinel/`.
- Read the tool's README before changing behavior: [README.md](README.md), [keyboardLeds/README.md](keyboardLeds/README.md), [systemReport/README.md](systemReport/README.md), [systemUpdate/README.md](systemUpdate/README.md), or [wifisentinel/README.md](wifisentinel/README.md).

## Architecture

- Bash entry points load modules relative to their own directory via `BASH_SOURCE`; do not make them depend on the caller's working directory.
- Bash `lib/` files are sourced modules, not standalone commands. Keep module responsibilities separate and fail clearly when a required module is missing.
- `systemReport/lib/sections/` contains independent report sections. A new section requires both its section file and the registry entry in `systemReport/systemReport.sh`.
- `systemUpdate/lib/apps.sh` is the single table for application update channels; preserve its confirmation and report-only semantics.
- `wifisentinel` separates measurement (`probe.sh`), decisions (`assess.sh`), network-changing recovery (`recover.sh`), and orchestration (`flow.sh`). Keep that boundary intact.
- `wifisentinel/config` is parsed as data, not sourced as shell code. Preserve the allow-list parser and environment-variable override behavior.

## Validation

- There is no repository-wide test runner. Do not treat the VS Code `msbuild` task as a meaningful build for this Bash/Python repository.
- For Bash changes, run `bash -n` on the affected entry point/modules and `shellcheck -x` when available.
- Prefer read-only smoke checks first: `systemReport/systemReport.sh --nosudo`, `systemUpdate/systemUpdate.sh --status`, and `wifisentinel/wifisentinel.sh --probe`.
- For Python changes, use the `keyboardLeds` virtual environment and validate imports or the narrowest relevant command before running hardware-dependent code.
- Hardware and network tools may require Arch Linux, NetworkManager, TUXEDO hardware, root access, or commands such as `nmcli`, `iw`, `evdev`, and `hidraw`; document unavailable environment prerequisites instead of weakening checks.

## Safety

- Treat `systemUpdate --system` as a mutating operation: it can invoke `sudo`, `pacman`, `yay`, firmware updates, and DKMS. Never run it as validation without explicit user intent.
- Treat `wifisentinel` recovery modes as mutating: `nmcli` can reconnect interfaces, renew DHCP, and toggle WiFi radio. Use `--probe` for read-only diagnosis.
- `systemReport` output can contain sensitive network, user, log, hardware, and configuration data. Do not publish or paste generated reports without reviewing them.
- Do not delete `.pacnew`/`.pacsave` files or add destructive cleanup behavior. Existing cleanup policies are documented in the tool README files.
- Preserve each tool's configuration model: tracked defaults for `systemReport` and `systemUpdate`; personal, ignored configuration for `wifisentinel`.

## Change Discipline

- Keep public flags, environment variable names, output formats, and documented safety guarantees backward compatible unless the task explicitly changes them.
- Update the affected README or TODO when behavior, flags, configuration, or verification status changes.
- Avoid broad formatting or refactoring in unrelated tools.
