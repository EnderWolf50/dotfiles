# =============================================================================
# Functions
# =============================================================================

if ($IsInteractiveConsole) {

  # GNU touch: bumps the modification time, or creates the file (not its folder). Takes any
  # number of paths, taken literally (`[` in a name is not a wildcard), and prints nothing.
  function touch {
    foreach ($p in $args) {
      $item = Get-Item -LiteralPath $p -Force -ErrorAction Ignore
      if ($item) {
        $item.LastWriteTime = Get-Date
      } else {
        $null = New-Item -ItemType File -Path $p
      }
    }
  }

  # GNU-style `ln [-s] [-f] <target> [link]`: a hard link by default, a symbolic link with -s,
  # and -f replaces an existing file or link (never a real directory). The target is stored
  # as an absolute path. A link path that is an existing directory gets the link inside it.
  # Symbolic links need Developer Mode (on here); without it a directory falls back to a
  # junction. Skipped: -r (relative targets), add it when a link has to survive a move.
  function ln {
    $symbolic = $force = $false
    $paths = @(foreach ($a in $args) {
        if ($a -match '^-([sf]+)$') {
          $symbolic = $symbolic -or $Matches[1].Contains('s')
          $force = $force -or $Matches[1].Contains('f')
        } else {
          $a
        }
      })
    if ($paths.Count -notin 1, 2) {
      Write-Error 'usage: ln [-s] [-f] <target> [link]'
      return
    }

    # Resolves `~` and relative paths without requiring the path to exist.
    $full = { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($args[0]) }
    $target = & $full $paths[0]
    $link = if ($paths.Count -eq 2) { & $full $paths[1] } else { Join-Path $PWD (Split-Path $target -Leaf) }

    $existing = Get-Item -LiteralPath $link -Force -ErrorAction Ignore
    if ($existing -and $existing.PSIsContainer -and -not ($existing.LinkType -and $force)) {
      $link = Join-Path $link (Split-Path $target -Leaf)
      $existing = Get-Item -LiteralPath $link -Force -ErrorAction Ignore
    }
    if ($existing) {
      if (-not $force) {
        Write-Error "ln: '$link' already exists (-f replaces it)"
        return
      }
      if ($existing.PSIsContainer -and -not $existing.LinkType) {
        Write-Error "ln: '$link' is a directory, not replacing it"
        return
      }
      # On a link, Delete() removes the link itself, not what it points to.
      $existing.Delete()
    }

    try {
      $null = New-Item -ItemType $(if ($symbolic) { 'SymbolicLink' } else { 'HardLink' }) -Path $link -Target $target -ErrorAction Stop
    } catch {
      if (-not ($symbolic -and (Test-Path -LiteralPath $target -PathType Container))) { throw }
      $null = New-Item -ItemType Junction -Path $link -Target $target
    }
    "$link -> $target"
  }

  # `conf <name>` jumps to a tool's config folder, `-o` opens it in Explorer instead and `-e`
  # in the editor. `conf` alone lists them; Tab completes the names. Add a machine-only one
  # from a `*.local.ps1` fragment: `$ConfDirs.work = 'D:\Work\.config'`.
  $ConfDirs = [ordered]@{
    chezmoi  = "$HOME\.local\share\chezmoi"
    claude   = "$HOME\.claude"
    codex    = "$HOME\.codex"
    opencode = "$HOME\.config\opencode"
    agents   = "$HOME\.agents"
    herdr    = "$HOME\.config\herdr"
    hermes   = "$HOME\.hermes"
    mise     = "$HOME\.config\mise"
    nvim     = "$Env:LOCALAPPDATA\nvim"
  }

  function conf {
    param(
      [ArgumentCompleter({ param($c, $p, $word) $ConfDirs.Keys -like "$word*" })]
      [string]$Name,
      [Alias('o')][switch]$Open,
      [Alias('e')][switch]$Edit
    )

    if (-not $Name) {
      return $ConfDirs.GetEnumerator() | ForEach-Object { '{0,-10} {1}' -f $_.Key, $_.Value }
    }
    $dir = $ConfDirs[$Name]
    if (-not $dir) {
      Write-Error "conf: unknown '$Name', one of: $($ConfDirs.Keys -join ', ')"
      return
    }
    if ($Open) { Invoke-Item -LiteralPath $dir }
    elseif ($Edit) { & $Env:EDITOR $dir }
    else { Set-Location -LiteralPath $dir }
  }

  function which
  {
    Param(
      [Parameter(Mandatory=$true)]
      [string]$Command
    )

    Get-Command -Name $Command -ErrorAction SilentlyContinue |
      Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue
  }

  # UTF-8 text <-> Base64, from an argument or the pipeline: `'hi' | b64enc`, `b64dec aGk=`.
  function ConvertTo-Base64 {
    param([Parameter(Mandatory, ValueFromPipeline)][string]$Text)
    process { [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Text)) }
  }

  function ConvertFrom-Base64 {
    param([Parameter(Mandatory, ValueFromPipeline)][string]$Base64)
    process { [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Base64)) }
  }

  Set-Alias -Name b64enc -Value ConvertTo-Base64 -Scope Global
  Set-Alias -Name b64dec -Value ConvertFrom-Base64 -Scope Global
}
