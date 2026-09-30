# =============================================================================
# Navigation
# =============================================================================

if ($IsInteractiveConsole) {

  # --- shortcuts ---
  # Directory shortcuts (oh-my-zsh). `cd -` already works natively in PowerShell 7.
  function .. { Set-Location .. }
  function ... { Set-Location ../.. }
  function .... { Set-Location ../../.. }
  # cd-extras is installed on this machine and exports a `~` alias (`Undo-Location`), so a
  # lone `~` would silently auto-load that module (~330 ms). Defining `~` here prevents it.
  function ~ { Set-Location $HOME }

  # --- auto cd ---
  # AUTO_CD (zsh): typing a directory name at the prompt changes into it. It runs only when
  # nothing else matches the name, only for input typed at the prompt (not scripts), and only
  # when the word resolves to an existing directory (relative to the current directory, or
  # absolute / `~/x`). A typo never jumps anywhere and nothing is searched for. zoxide
  # records the new location through its own hook, so these directories also feed `z` and `zi`.
  $previousCommandNotFound = $ExecutionContext.InvokeCommand.CommandNotFoundAction
  $ExecutionContext.InvokeCommand.CommandNotFoundAction = {
    param($sender, $e)

    $target = $null
    if ($e.CommandOrigin -eq 'Runspace' -and $e.CommandName) {
      $target = $e.CommandName
      # `Test-Path -LiteralPath` does not expand `~`, so do it here (a lone `~` is the function
      # above).
      # Only `~/x` reaches this handler: PowerShell reads `~\x` as `module\command`.
      if ($target -like '~/*') {
        $target = Join-Path $HOME $target.Substring(2)
      }
    }

    if ($target -and (Test-Path -LiteralPath $target -PathType Container)) {
      $e.CommandScriptBlock = { Set-Location -LiteralPath $target }.GetNewClosure()
      $e.StopSearch = $true
    } elseif ($previousCommandNotFound) {
      $previousCommandNotFound.Invoke($sender, $e)
    }
  }.GetNewClosure()
}
