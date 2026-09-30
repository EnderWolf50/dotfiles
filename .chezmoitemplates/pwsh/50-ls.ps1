# =============================================================================
# ls & tree (eza)
# =============================================================================

# `ls` becomes eza with icons. Aliases win over functions in command resolution, so the
# built-in `ls` alias has to go first. Piped output is not a TTY, so eza drops icons and
# colors on its own. Use `gci` / `dir` when you need objects, `ls -a` to show dotfiles.
if ($IsInteractiveConsole -and (has eza)) {
  # --- argument handling ---
  # `ls` has to make sense to PowerShell and to zsh habits, so its arguments are sorted
  # out before eza sees them:
  #   - PowerShell parameters (`-Force`, `-Recurse`, `-Filter *.md`, ...) hand the whole
  #     call to `Get-ChildItem`, exactly like the built-in `ls` did. eza cannot use them.
  #   - GNU flags whose eza spelling differs are translated: `-t`, `-S`, `-X`, `-U`, `-r`,
  #     `-F`, `-h` and `--sort=...`. The resulting order was checked against GNU ls.
  #   - Wildcards are expanded here, because neither PowerShell nor eza does it for a
  #     native program. Limitation: `**` is not recursive (PowerShell has no globstar).
  # Differences that remain: pipelines carry text instead of objects, and dotfiles stay
  # hidden unless you pass `-a`.

  # True when a word is a Get-ChildItem parameter. PowerShell accepts unambiguous prefixes
  # (`-Rec`), so a word of 3+ letters that starts a parameter name counts. A GNU bundle
  # that happens to spell such a prefix (e.g. `-lit`) is treated as PowerShell; that is rare.
  function Test-PowerShellLsArgs {
    $known = 'Path', 'LiteralPath', 'Filter', 'Include', 'Exclude', 'Recurse', 'Depth', 'Force',
      'Name', 'Attributes', 'FollowSymlink', 'Directory', 'File', 'Hidden', 'ReadOnly', 'System',
      'UseTransaction', 'Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction',
      'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer',
      'PipelineVariable', 'ProgressAction'
    foreach ($a in $args) {
      if ($a -is [string] -and $a -match '^-([A-Za-z]{3,})(:.*)?$') {
        $word = $Matches[1]
        foreach ($k in $known) {
          if ($k.StartsWith($word, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
      }
    }
    $false
  }

  # Expands `*`, `?` and `[` patterns. Flags and existing literal paths pass through
  # untouched, and a pattern with no match is passed on as-is.
  function Expand-GlobArgs {
    foreach ($a in $args) {
      if ($a -is [string] -and $a -notlike '-*' -and $a -match '[*?\[]' -and
          -not (Test-Path -LiteralPath $a)) {
        $found = @(Resolve-Path -Path $a -Relative -ErrorAction SilentlyContinue)
        # A trailing slash means directories only (Resolve-Path ignores it).
        if ($a -match '[\\/]$') {
          $found = @($found | Where-Object { Test-Path -LiteralPath $_ -PathType Container })
        }
        if ($found.Count) { $found } else { $a }
      } else {
        $a
      }
    }
  }

  # GNU sorts by time and size newest/largest first, while eza sorts every key ascending,
  # so `-t` and `-S` need `--reverse`, and a user `-r` flips that again.
  function ConvertTo-EzaArgs {
    $out = [System.Collections.Generic.List[object]]::new()
    $sortKey = $null      # modified, size, extension or none
    $descending = $false  # GNU's own direction for that key
    $reverse = $false     # the user's -r / --reverse
    $literal = $false     # after `--`, everything passes through
    $valueNext = $false   # the next word is the value of an option such as -I

    for ($n = 0; $n -lt $args.Count; $n++) {
      $a = $args[$n]

      if ($literal -or $valueNext -or $a -isnot [string]) {
        $out.Add($a)
        $valueNext = $false
        continue
      }
      if ($a -eq '--') {
        $literal = $true
        $out.Add($a)
        continue
      }

      if ($a.StartsWith('--')) {
        switch -Regex ($a) {
          '^--human-readable$' { }                     # eza sizes are already human-readable
          '^--directory$' { $out.Add('-d') }
          '^--classify$' { $out.Add('--classify=always') }
          '^--reverse$' { $reverse = $true }
          '^--sort=(size|time|extension|none)$' {
            switch ($Matches[1]) {
              'size' { $sortKey = 'size'; $descending = $true }
              'time' { $sortKey = 'modified'; $descending = $true }
              'extension' { $sortKey = 'extension'; $descending = $false }
              'none' { $sortKey = 'none'; $descending = $false }
            }
          }
          default {
            $out.Add($a)
            if ($a -eq '--ignore-glob') { $valueNext = $true }
          }
        }
        continue
      }

      if ($a -match '^-[A-Za-z0-9]+$') {
        $keep = ''
        for ($i = 1; $i -lt $a.Length; $i++) {
          $c = [string]$a[$i]
          switch -CaseSensitive ($c) {
            'h' { }                                    # human-readable is eza's default
            'S' { $sortKey = 'size'; $descending = $true }
            'X' { $sortKey = 'extension'; $descending = $false }
            'U' { $sortKey = 'none'; $descending = $false }
            'r' { $reverse = $true }
            'F' { $out.Add('--classify=always') }
            't' {
              # eza's own `-t <field>` picks the time column; GNU's `-t` sorts by time.
              if ($n + 1 -lt $args.Count -and $args[$n + 1] -match '^(modified|changed|accessed|created)$') {
                $keep += $c
              } else {
                $sortKey = 'modified'
                $descending = $true
              }
            }
            default { $keep += $c }
          }
        }
        if ($keep) { $out.Add("-$keep") }
        # The value of -I is a glob and must not be expanded like a path.
        if ($a.EndsWith('I', [System.StringComparison]::Ordinal)) { $valueNext = $true }
        continue
      }

      foreach ($x in (Expand-GlobArgs $a)) { $out.Add($x) }
    }

    if ($sortKey) {
      $out.Add("--sort=$sortKey")
      if ($sortKey -ne 'none' -and ($reverse -xor $descending)) { $out.Add('--reverse') }
    } elseif ($reverse) {
      $out.Add('--reverse')
    }
    $out
  }

  # --- colors ---
  # eza reads `EZA_COLORS` ("code=SGR:code=SGR"); the roles come from `$Theme`. It accepts
  # 24-bit colors, although its man page only lists the 16 and 256-color codes.
  $env:EZA_COLORS = ($Theme.Eza | ForEach-Object {
      $code, $spec = $_ -split '=', 2
      '{0}={1}' -f $code, (ConvertTo-SgrParams $spec)
    }) -join ':'

  # --- ls ---
  Remove-Item Alias:\ls -Force -ErrorAction SilentlyContinue
  function ls {
    if (Test-PowerShellLsArgs @args) {
      Get-ChildItem @args
    } else {
      eza --icons @(ConvertTo-EzaArgs @args)
    }
  }
  function ll { eza --icons -l --git @(ConvertTo-EzaArgs @args) }
  function la { eza --icons -la --git @(ConvertTo-EzaArgs @args) }
  # `lt`: two levels, skipping what `.gitignore` excludes.
  function lt { eza --icons -T --level=2 --git-ignore @(ConvertTo-EzaArgs @args) }

  # --- tree ---
  # `tree` stops at 3 levels by default so a stray call in a big directory stays readable.
  # Later flags win, so `tree -L 6` overrides it. Useful eza flags: `-L <n>` depth, `-D`
  # dirs only, `-I 'a|b'` exclude globs, `-a` hidden files, `--git-ignore` honor `.gitignore`.
  function tree { eza --icons -T -L 3 @(ConvertTo-EzaArgs @args) }
}
