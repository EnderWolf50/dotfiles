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
# pathed.exe changes the saved PATH, but a child process cannot touch this shell's `$env:PATH`.
# The wrapper compares the saved PATH before and after and applies the difference here, so
# session-only entries (mise's) stay. A new entry goes to the end, whatever its saved position.
if ($IsInteractiveConsole) {
  function pathed {
    $saved = { ('Machine', 'User' | ForEach-Object { [Environment]::GetEnvironmentVariable('Path', $_) }) -join ';' -split ';' | Where-Object { $_ } }
    $before = & $saved
    pathed.exe @args
    $after = & $saved
    $session = @($env:PATH -split ';' | Where-Object { $_ -and ($_ -in $after -or $_ -notin $before) })
    $env:PATH = ($session + @($after | Where-Object { $_ -notin $before -and $_ -notin $session })) -join ';'
  }
}
