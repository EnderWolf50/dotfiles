# dotfiles

Managed with [chezmoi](https://www.chezmoi.io/). Windows (PowerShell 7) and Linux / WSL (zsh).

## New machine

```sh
# Windows
winget install twpayne.chezmoi
# Linux / WSL
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin

chezmoi init --apply EnderWolf50
```

`init` asks a few questions once (see `.chezmoi.toml.tmpl`) and writes
`~/.config/chezmoi/chezmoi.toml`.

Windows only, in a new PowerShell window: `tools -Missing` lists what the profile needs but
is not installed, `tools -Install` installs it (winget / scoop / npm / PSGallery). The list is
`.chezmoidata/tools.toml`. Creating the `%LOCALAPPDATA%\nvim` symlink needs Developer Mode
(or an elevated shell).

## Layout

| Path | What |
|---|---|
| `.chezmoidata/themes.toml` | The one color scheme (vesper) for every tool that has colors |
| `.chezmoidata/prompt.toml` | starship symbol presets (`unicode` / `ascii`) |
| `.chezmoidata/tools.toml` | Programs the PowerShell profile uses |
| `.chezmoitemplates/pwsh/` | PowerShell profile fragments, assembled by `Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl`; `*.local.ps1` there is machine-local and git-ignored |
| `dot_config/` | starship, nvim (LazyVim), lazygit, herdr: shared by Windows and Linux |
| `private_dot_zshrc`, `private_dot_zimrc`, `dot_zprofile`, `dot_tmux.conf.tmpl` | Linux / WSL shell |
| `.chezmoiignore` | What each OS skips |

## Per-machine overrides

In `~/.config/chezmoi/chezmoi.toml`:

```toml
[data]
theme = "other"          # a theme defined in themes.toml

[data.prompt]
preset = "ascii"
```
