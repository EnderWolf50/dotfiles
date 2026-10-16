# =============================================================================
# Tool status
# =============================================================================
# Generated from `.chezmoidata/tools.toml`. `Show-Tools` (alias `tools`) reports which of the
# programs and modules this profile uses are installed on this machine; add `-Missing` for
# only the ones that are not, and `-Install` to install those after asking.
if ($IsInteractiveConsole) {
  $DotTools = @(
{{- range $tool := .tools }}
{{- if and (ne (index $tool "os" | default "") "linux") (or (not (index $tool "personal" | default false)) (and (hasKey $ "personal") $.personal)) }}
    @{
      Name      = '{{ $tool.name | replace "'" "''" }}'
      Check     = '{{ index $tool "check" | default "" | replace "'" "''" }}'
      Kind      = '{{ index $tool "kind" | default "command" }}'
      Purpose   = '{{ $tool.purpose | replace "'" "''" }}'
      UsedBy    = '{{ $tool.used_by | replace "'" "''" }}'
      Winget    = '{{ index $tool "winget" | default "" }}'
      Scoop     = '{{ index $tool "scoop" | default "" }}'
      Npm       = '{{ index $tool "npm" | default "" }}'
      PSGallery = '{{ index $tool "psgallery" | default "" }}'
      Go        = '{{ index $tool "go" | default "" }}'
      Note      = '{{ index $tool "note" | default "" | replace "'" "''" }}'
      After     = '{{ index $tool "after" | default "" | replace "'" "''" }}'
    }
{{- end }}
{{- end }}
  )

  # The command that would install a tool, or nothing when no package manager is known.
  function Get-ToolInstallCommand {
    param($Tool)

    if ($Tool.Scoop) { "scoop install $($Tool.Scoop)" }
    elseif ($Tool.Winget) { "winget install --id $($Tool.Winget) -e" }
    # pnpm rather than npm -g: npm puts a global package in the current Node's folder, which the
    # next Node upgrade replaces; pnpm keeps it under PNPM_HOME.
    elseif ($Tool.Npm) { "pnpm add -g $($Tool.Npm)" }
    elseif ($Tool.PSGallery) { "Install-PSResource $($Tool.PSGallery) -Scope CurrentUser -TrustRepository" }
    # Into ~/.local/bin rather than GOBIN: mise points GOBIN at the current Go's own folder,
    # which the next Go upgrade replaces.
    elseif ($Tool.Go) { "`$env:GOBIN = `"`$HOME\.local\bin`"; go install $($Tool.Go)@latest; Remove-Item Env:GOBIN" }
  }

  function Show-Tools {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
      [switch]$Missing,
      [switch]$Install,
      [switch]$PassThru
    )

    $rows = foreach ($tool in $DotTools) {
      $found = if (-not $tool.Check) {
        $null
      } elseif ($tool.Kind -eq 'module') {
        [bool](Get-Module -ListAvailable -Name $tool.Check)
      } else {
        [bool](Get-Command $tool.Check -CommandType Application, ExternalScript -ErrorAction Ignore)
      }
      [pscustomobject]@{
        Installed = if ($null -eq $found) { '?' } elseif ($found) { 'yes' } else { 'NO' }
        Name      = $tool.Name
        Purpose   = $tool.Purpose
        UsedBy    = $tool.UsedBy
        Install   = Get-ToolInstallCommand $tool
        Tool      = $tool
      }
    }

    $shown = if ($Missing) { @($rows | Where-Object Installed -eq 'NO') } else { @($rows) }
    $absent = @($rows | Where-Object Installed -eq 'NO')

    if ($Install) {
      $installed = @()
      foreach ($row in $absent) {
        if (-not $row.Install) {
          Write-Warning "$($row.Name): no package manager entry, see $($row.Tool.Note)"
          continue
        }
        if ($PSCmdlet.ShouldProcess($row.Name, $row.Install)) {
          # A scoop app may live in a bucket that is not added yet.
          if ($row.Tool.Scoop -match '^([^/]+)/') {
            scoop bucket add $Matches[1] 2>$null
          }
          # winget would otherwise stop to ask about the package and source agreements.
          $command = $row.Install
          if ($command.StartsWith('winget ')) {
            $command += ' --accept-package-agreements --accept-source-agreements'
          }
          $global:LASTEXITCODE = 0
          Invoke-Expression $command
          if ($? -and $LASTEXITCODE -eq 0) { $installed += $row }
        }
      }
      # What the tools installed just now still need once (`after` in tools.toml).
      if ($installed.Count) {
        $steps = @($installed | Where-Object { $_.Tool.After } | ForEach-Object { $_.Tool.After })
        if ($steps.Count) {
          Write-Host 'To do once for what was just installed:'
          $steps | ForEach-Object { Write-Host "  $_" }
        }
        Write-Host 'Open a new PowerShell window to pick up the new commands.'
      }
      return
    }

    if ($PassThru) { return $shown | Select-Object Installed, Name, Purpose, UsedBy, Install }

    if ($Missing -and -not $shown.Count) {
      Write-Host 'Everything this profile uses is installed.'
      return
    }
    $shown | Format-Table -AutoSize -Wrap Installed, Name, UsedBy, Purpose | Out-String -Width 200 | Write-Host
    # The install commands are long, so they are listed under the table rather than in it.
    if ($absent.Count) {
      Write-Host 'Not installed:'
      foreach ($row in $absent) {
        $how = if ($row.Install) { $row.Install } elseif ($row.Tool.Note) { $row.Tool.Note } else { $row.Tool.Url }
        Write-Host ('  {0,-16} {1}' -f $row.Name, $how)
      }
      Write-Host ''
    }
    $checked = @($rows | Where-Object Installed -ne '?')
    Write-Host ("{0} of {1} checkable tools installed; '?' means it cannot be checked from PowerShell." -f
        @($checked | Where-Object Installed -eq 'yes').Count, $checked.Count)
  }

  Set-Alias -Name tools -Value Show-Tools -Scope Global
}
