# =============================================================================
# Helpers
# =============================================================================

# True only in a real terminal session: ConsoleHost with stdin, stdout and stderr all
# attached. Scripts, CI and agent shells fail this, so they skip the interactive setup.
function Test-InteractiveConsole {
  $Host.Name -eq 'ConsoleHost' -and
    -not [Console]::IsInputRedirected -and
    -not [Console]::IsOutputRedirected -and
    -not [Console]::IsErrorRedirected
}

$IsInteractiveConsole = Test-InteractiveConsole

# `has git` is the PowerShell version of `command -v git` in bash and zsh: true when the
# name resolves to a command, alias, function or executable. Slow for names that do not
# exist (~30 ms each: PowerShell searches every installed module), so do not call it in a
# loop over commands that are likely missing.
function has {
  param([Parameter(Mandatory = $true)][string]$Name)

  [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# Imports a module when it is installed and stays silent when it is not (fresh machine).
function Import-OptionalModule {
  param([Parameter(Mandatory = $true)][string]$Name)

  # `-Global` imports into the session instead of the scope of this function.
  Import-Module $Name -Global -ErrorAction SilentlyContinue
}
