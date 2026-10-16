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

Windows: every apply installs the tools in `.chezmoidata/tools.toml` that are missing (scoop / winget /
npm / PSGallery / go, `run_before_install-tools.ps1`). In a PowerShell window, `tools -Missing` lists
what is still not installed. Creating the `%LOCALAPPDATA%\nvim` symlink needs Developer Mode
(or an elevated shell).

Linux / WSL: every apply installs zsh (apt, made the login shell), Homebrew, and the `brew` / `cask` /
`npm` packages in `tools.toml` that are missing (`run_before_install-tools.sh`); the first one asks for
the sudo password. After the files, `run_onchange_after_mise-install.*` installs the tools in
the shared mise config (`dot_config/mise/config.toml.tmpl`: node, uv, java on a java machine, ...), on Windows too.

## Layout

| Path | What |
|---|---|
| `.chezmoidata/themes.toml` | The one color scheme (vesper) for every tool that has colors |
| `.chezmoidata/prompt.toml` | starship symbol presets (`unicode` / `ascii`) |
| `.chezmoidata/tools.toml` | Programs the PowerShell profile and Claude Code use (CLIs, language servers by `lang`); npm-registry ones install with `pnpm add -g` |
| `.chezmoidata/statusline.toml` | Claude Code statusline options (`preset` layout, `theme` colors, `icons`) |
| `.chezmoidata/skills.toml` | Global agent skills (`skills` CLI), as folder paths inside each source repo; `run_onchange_after_sync-skills.*` sparse-clones only those folders, installs them from the clone and removes the rest, on change and on the first apply of each day |
| `.chezmoidata/claude.toml` | Claude Code settings kept the same everywhere: set / merged / seeded / appended keys of `settings.json`, the LSP plugin per language, and the user-scope MCP servers (`[claude.mcp]`, registered by `run_onchange_after_claude-mcp.*`). Removing a key here does not remove it from `settings.json` |
| `.chezmoitemplates/agent-instructions.md.tmpl` | Shared global instructions, rendered as `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`, with tool-specific adapters |
| `dot_codex/`, `run_after_codex-settings.*` | Codex instructions and a comment-preserving settings sync helper; every apply merges shared MCP connections, Claude instruction fallback and shared shell environment into the local Codex config |
| `.chezmoitemplates/pwsh/` | PowerShell profile fragments, assembled by `Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl`; `*.local.ps1` there is machine-local and git-ignored |
| `dot_config/` | starship, nvim (LazyVim), lazygit, herdr, ripgrep (Claude Code sessions only, via `RIPGREP_CONFIG_PATH`): shared by Windows and Linux |
| `dot_claude/` | Claude Code: `CLAUDE.md` (your own instructions), agents, statusline, theme (`custom:vesper`, one file per theme), and the `settings.json` keys from `claude.toml` (the rest of that file, such as `autoMode.environment`, stays Claude Code's) |
| `private_dot_zshrc`, `private_dot_zimrc`, `dot_zprofile`, `dot_tmux.conf.tmpl` | Linux / WSL shell |
| `dot_local/bin/executable_cua-driver`, `dot_claude/skills/symlink_cua-driver.tmpl` | WSL only: run the Windows cua-driver (paths in `call` JSON turned into Windows paths) and link the skill its `skills install` fetched, so a WSL agent drives the Windows desktop |
| `.chezmoiignore` | What each OS skips |
| `run_after_claude-settings-drift.*` | After every apply, lists the plugins and marketplaces in `~/.claude/settings.json` that `claude.toml` does not know (a removal made on another machine, or a local `/plugin` install), and on a terminal asks whether to remove each one. `[claude.local]` in `claude.toml` holds the ones a machine keeps on purpose |
| `.github/check.py` | Renders every target (`chezmoi archive`) and syntax-checks it, and pins how `modify_settings.json` appends lists and sets LSP plugins; the pre-commit hook (`.lefthook.yml`, enable with `lefthook install`) runs it on this OS, CI on Linux |

## Claude Code and Codex

Both agents use the same global instructions and skills. Edit the shared instructions in
`.chezmoitemplates/agent-instructions.md.tmpl`; its adapters keep Claude's tool names and model aliases
out of Codex instructions. The existing skills sync installs into `~/.agents/skills` for Codex and links
them for Claude Code. In Codex, use `$skill-name` or `/skills`; Claude's `/skill-name` syntax is not copied.
The Codex instructions also ask it to read matching skill patches and project-only Claude skills or
commands when needed. This is instruction-based adaptation, not Claude's plugin hook execution.

Every apply runs `uv run --no-project --script ~/.codex/sync-settings.py`. The script pins TOML Kit
in its inline dependency metadata and merges only:

- `CLAUDE.md` into `project_doc_fallback_filenames`, keeping existing fallbacks. Codex discovers it
  only where `AGENTS.md` is absent; the global instructions explain how to consult additional Claude
  guidance and `@path` imports when needed.
- MCP connection fields from `[claude.mcp]` in `.chezmoidata/claude.toml` (currently Semble and isolated
  Playwright). Other servers, and policy fields such as `enabled` on shared servers, stay local.
- `LEFTHOOK_OUTPUT` from the Claude environment settings into Codex's shell environment.

`~/.codex/config.toml` remains a local file: models, providers, desktop preferences, hooks, trust,
plugins and unrelated settings and comments are preserved. Before each change the helper saves
`config.toml.bak-YYYYMMDD-HHMMSS-microseconds`; unchanged applies do not rewrite it. Removing an MCP
entry from the shared list does not delete its existing registration from either agent.

Restart Codex or start a new CLI session after applying. This setup covers local Codex installations;
hosted sessions and third-party harnesses may supply their own instructions, tools and configuration.
Claude-specific permissions/auto mode, plugins, LSP plugins, agents, hooks, themes and statusline are
separate integrations and are not translated by this sync.

Verified against the official [instruction discovery guide](https://learn.chatgpt.com/docs/agent-configuration/agents-md),
[configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference), and
[skills guide](https://learn.chatgpt.com/docs/build-skills).
Run `python .github/check.py` and `uv run --no-project --script .github/check-codex.py` to validate
rendered files, settings preservation, backups, idempotency and the instructions for both OSes.

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
