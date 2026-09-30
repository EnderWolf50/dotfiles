# =============================================================================
# Unix tools
# =============================================================================

# Unix tools that ship with Git for Windows, as aliases: they exist only in interactive
# shells, so scripts keep the Windows behavior. `sort`, `find` and `diff` are left alone
# because the Windows versions behave differently and replacing them is a bigger change.
# These aliases shadow same-named programs on PATH. PATH is not checked first because
# `Get-Command` on a missing name costs ~30 ms each, which adds up over this list.
if ($IsInteractiveConsole) {
  # --- helpers ---
  # Git for Windows keeps its Unix tools in <root>\usr\bin. git.exe lives in <root>\cmd or
  # <root>\bin, so derive the root from it (works for any install root).
  function Get-GitUsrBin {
    $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue |
      Select-Object -First 1 -ExpandProperty Source
    if ($git)
    {
      $dir = Join-Path (Split-Path (Split-Path $git)) "usr\bin"
      if (Test-Path -LiteralPath $dir)
      {
        return $dir
      }
    }
  }

  # --- aliases ---
  # `<root>\cmd` is searched before `usr\bin`: for tig it holds the launcher that sets up
  # the MSYS environment, while `usr\bin` has the bare binary.
  $gitUsrBin = Get-GitUsrBin
  if ($gitUsrBin) {
    $gitDirs = @(
      [System.IO.Path]::Combine((Split-Path (Split-Path $gitUsrBin)), 'cmd'),
      $gitUsrBin
    )
    foreach ($tool in 'head', 'tail', 'wc', 'sed', 'awk', 'xargs', 'cut', 'tr', 'uniq', 'env', 'printenv', 'less', 'tig') {
      foreach ($dir in $gitDirs) {
        $exe = [System.IO.Path]::Combine($dir, "$tool.exe")
        if ([System.IO.File]::Exists($exe)) {
          Set-Alias -Name $tool -Value $exe -Scope Global
          break
        }
      }
    }
  }
}
