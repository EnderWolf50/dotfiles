# =============================================================================
# Prompt
# =============================================================================

# --- alternatives (not enabled) ---
# oh-my-posh
# oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\star.omp.json" | Invoke-Expression
# $env:POSH_GIT_ENABLED = $true

# --- starship ---
# Defines `prompt` outright, so it has to run before the tools that wrap it (mise and
# zoxide, see `80-tools.ps1`).
if ($IsInteractiveConsole -and (has starship)) {
  Invoke-Expression (&starship init powershell)
}
