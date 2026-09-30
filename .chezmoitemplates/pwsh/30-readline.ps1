# =============================================================================
# Readline & completion
# =============================================================================

if ($IsInteractiveConsole) {
  # --- look ---
  # Colors come from `$Theme` (see `15-theme.ps1`), so changing the theme needs no edit here.
  # One wrong role name makes PSReadLine reject the whole table, so say so instead of
  # failing silently.
  $colors = @{}
  foreach ($role in $Theme.PSReadLine.Keys) {
    $colors[$role] = ConvertTo-AnsiStyle $Theme.PSReadLine[$role]
  }
  try {
    Set-PSReadLineOption -Colors $colors -ErrorAction Stop
  } catch {
    Write-Warning "PSReadLine colors not applied: $($_.Exception.Message)"
  }
  Remove-Variable colors, role
  # No beep on errors or ambiguous completions.
  Set-PSReadLineOption -BellStyle None

  # --- suggestions ---
  # Inline gray suggestions from history (fish / zsh-autosuggestions). Right arrow or End
  # at the end of the line accepts the suggestion.
  Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView

  # --- keys ---
  Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
  # Up and Down search the history by what is already typed (fish / history-substring-search).
  Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
  Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

  # --- carapace ---
  # Also bridge completions from zsh, fish and bash (see carapace's `CARAPACE_BRIDGES`).
  $env:CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense'
  # Match case-insensitively, so `git CHEC<Tab>` still completes.
  $env:CARAPACE_MATCH = '1'
  # Show a candidate's description as a tooltip under the menu instead of after every name
  # (PowerShell only), and cut long descriptions at 60 characters (the median is ~40, the
  # longest ~80).
  $env:CARAPACE_TOOLTIP = '1'
  $env:CARAPACE_DESCRIPTION_LENGTH = '60'
  if (has carapace) {
    carapace _carapace | Out-String | Invoke-Expression
  }

  # --- psfzf ---
  # Ctrl+t inserts files, Ctrl+r searches the history. Keep this inline: the key bindings do
  # not stick when `Set-PsFzfOption` runs from a `PowerShell.OnIdle` event (i.e. deferred).
  # PSFzf hands `FZF_DEFAULT_OPTS` to fzf, so the look is set here: the theme's colors (`-1`
  # keeps the terminal's own background), and a compact box under the prompt instead of
  # full screen.
  $fzfColors = ($Theme.Fzf.GetEnumerator() | ForEach-Object { '{0}:{1}' -f $_.Key, $_.Value }) -join ','
  $env:FZF_DEFAULT_OPTS = @(
    "--color=$fzfColors"
    '--layout=reverse --height=40% --border=rounded --info=inline-right'
    '--prompt="❯ " --pointer="▌" --marker="✓"'
  ) -join ' '
  Remove-Variable fzfColors

  # Alt+c lists directories with fd. PSFzf's own default is `cmd /c dir /s/b/ad`, which walks
  # everything below the current directory (AppData and tool caches included) and feeds it
  # through the PowerShell pipeline: about 7 seconds in D:\Dev and a minute in the home
  # directory. Ctrl+t is unaffected, it uses fzf's own walker; `Set-PsFzfOption -EnableFd`
  # would make Ctrl+t slower too, so fd is wired in only here. The skipped names are caches
  # and package stores that are never a place to `cd` into; edit the list to taste.
  if (has fd) {
    $skipDirs = '.git', 'node_modules', 'AppData', '.cache', '.npm', '.nuget', '.cargo', '.rustup',
      '.gradle', '.m2', '__pycache__', '.venv', '.bun', '.unsloth'
    $env:FZF_ALT_C_COMMAND = 'fd.exe --type directory --hidden ' +
      (($skipDirs | ForEach-Object { "--exclude $_" }) -join ' ')
    Remove-Variable skipDirs
  }

  Import-OptionalModule PSFzf
  if (has Set-PsFzfOption) {
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' `
      -PSReadlineChordReverseHistory 'Ctrl+r'
  }

  # Not enabled: Tab stays on `MenuComplete` for carapace, and this would override it.
  # Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
}
