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

Linux / WSL: every apply installs zsh (apt, made the login shell), Homebrew, and the `brew` / `cask` /
`npm` packages in `tools.toml` that are missing (`run_before_install-tools.sh`); the first one asks for
the sudo password. After the files, `run_onchange_after_mise-install.sh` installs the tools in
the shared mise config (`dot_config/mise/config.toml`: node, uv, ...); on Windows, run `mise install`.

## Layout

| Path | What |
|---|---|
| `.chezmoidata/themes.toml` | The one color scheme (vesper) for every tool that has colors |
| `.chezmoidata/prompt.toml` | starship symbol presets (`unicode` / `ascii`) |
| `.chezmoidata/tools.toml` | Programs the PowerShell profile and Claude Code use (CLIs, language servers by `lang`); npm-registry ones install with `pnpm add -g` |
| `.chezmoidata/statusline.toml` | Claude Code statusline options (`preset` layout, `theme` colors, `icons`) |
| `.chezmoidata/skills.toml` | Global agent skills (`skills` CLI); `run_onchange_after_sync-skills.*` installs the list and removes the rest on change; `run_onchange_after_update-skills.*` updates them on the first apply of each day |
| `.chezmoidata/claude.toml` | Claude Code settings kept the same everywhere: set / merged / seeded / appended keys of `settings.json`, the LSP plugin per language, and the user-scope MCP servers (`[claude.mcp]`, registered by `run_onchange_after_claude-mcp.*`). Removing a key here does not remove it from `settings.json` |
| `.chezmoitemplates/pwsh/` | PowerShell profile fragments, assembled by `Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl`; `*.local.ps1` there is machine-local and git-ignored |
| `dot_config/` | starship, nvim (LazyVim), lazygit, herdr, ripgrep (Claude Code sessions only, via `RIPGREP_CONFIG_PATH`): shared by Windows and Linux |
| `dot_claude/` | Claude Code: `CLAUDE.md` (your own instructions), agents, statusline, theme (`custom:vesper`, one file per theme), and the `settings.json` keys from `claude.toml` (the rest of that file, such as `autoMode`, stays Claude Code's) |
| `private_dot_zshrc`, `private_dot_zimrc`, `dot_zprofile`, `dot_tmux.conf.tmpl` | Linux / WSL shell |
| `.chezmoiignore` | What each OS skips |
| `run_after_claude-settings-drift.*` | After every apply, lists the plugins and marketplaces in `~/.claude/settings.json` that `claude.toml` does not know (a removal made on another machine, or a local `/plugin` install), and on a terminal asks whether to remove each one. `[claude.local]` in `claude.toml` holds the ones a machine keeps on purpose |
| `.github/check.py` | Renders every target (`chezmoi archive`) and syntax-checks it, and pins how `modify_settings.json` appends lists and sets LSP plugins; the pre-commit hook (`.lefthook.yml`, enable with `lefthook install`) runs it on this OS, CI on Linux |

## Per-machine overrides

`chezmoi init` asks which languages the machine works in and stores them as `languages`. Every apply turns on those languages' LSP plugins and turns the rest off (`[claude.lsp]` in `.chezmoidata/claude.toml`), and `tools` lists only their language servers (`lang` in `tools.toml`). Rerun `chezmoi init` to change the answer.

In `~/.config/chezmoi/chezmoi.toml`:

```toml
[data]
theme = "other"          # a theme defined in themes.toml

[data.prompt]
preset = "ascii"

[data.statusline]
preset = "lean"        # layout: vesper | lean | rainbow | classic
theme = "p10k"         # colors: vesper (themes.toml) | p10k
icons = false          # terminal font without Nerd Font glyphs
```
