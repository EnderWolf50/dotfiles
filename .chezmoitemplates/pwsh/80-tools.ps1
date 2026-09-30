# =============================================================================
# Tools
# =============================================================================
# These must come after `20-prompt.ps1`: starship defines `prompt`, while mise and zoxide
# save the current `prompt` and wrap it, so running them earlier would lose their hooks.

# --- mise ---
# Runs in non-interactive shells too, so mise-managed tools stay on PATH.
if (has mise) {
  mise activate pwsh | Out-String | Invoke-Expression
}

# --- zoxide ---
if ($IsInteractiveConsole -and (has zoxide)) {
  Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# --- gsudo ---
# Gives `gsudo` / `Invoke-Gsudo` a PowerShell wrapper (scriptblocks, the current directory).
# It does not touch `prompt`, so its position here does not matter. Interactive only: the
# import costs ~150 ms and scripts do not need it.
if ($IsInteractiveConsole) {
  Import-OptionalModule gsudoModule
}

# --- pathed ---
# Defines a `pathed` function that runs pathed.exe and then applies its change to this
# shell's `$env:PATH` too (a child process cannot).
if ($IsInteractiveConsole -and (has pathed)) {
  pathed.exe init pwsh | Out-String | Invoke-Expression
}
