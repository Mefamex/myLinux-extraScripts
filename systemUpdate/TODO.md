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
