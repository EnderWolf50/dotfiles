# =============================================================================
# Theme
# =============================================================================
# Generated from `.chezmoidata/themes.toml` (theme: {{ .theme }}). Change colors by editing that
# file, or pick another theme with `theme = "..."` (per machine: `[data]` in chezmoi.toml),
# then run `chezmoi apply`. Everything with colors reads `$Theme`, so a new theme needs no
# code change.
{{- $palette := (index .themes .theme).palette }}

if ($IsInteractiveConsole) {
  # --- helpers ---
  # A spec is a list of words: a color as `#rrggbb` (`fg:` / `bg:` in front picks the layer,
  # foreground by default) and the modifiers `bold`, `dim`, `italic`, `underline`.
  # `ConvertTo-SgrParams` gives the ANSI parameters (`3;38;2;255;199;153`) and
  # `ConvertTo-AnsiStyle` wraps them into an escape sequence.
  function ConvertTo-SgrParams {
    param([string]$Spec)

    $codes = foreach ($word in $Spec -split ' ') {
      if ($word -match '^(?:(fg|bg):)?#([0-9a-fA-F]{6})$') {
        $rgb = [Convert]::ToInt32($Matches[2], 16)
        '{0};2;{1};{2};{3}' -f $(if ($Matches[1] -eq 'bg') { 48 } else { 38 }),
          (($rgb -shr 16) -band 255), (($rgb -shr 8) -band 255), ($rgb -band 255)
      } else {
        switch ($word) {
          'bold' { 1 }
          'dim' { 2 }
          'italic' { 3 }
          'underline' { 4 }
          default { Write-Warning "Unknown theme word '$word' in '$Spec'" }
        }
      }
    }
    $codes -join ';'
  }

  function ConvertTo-AnsiStyle {
    param([string]$Spec)

    "`e[$(ConvertTo-SgrParams $Spec)m"
  }

  # --- colors ---
  $Theme = @{
    Name       = '{{ .theme }}'
    Palette    = @{
{{- range $key, $color := $palette }}
      '{{ $key }}' = '{{ $color }}'
{{- end }}
    }
    PSReadLine = @{
{{- range $role, $spec := .roles.psreadline }}
      '{{ $role }}' = '{{ template "theme/spec" (dict "palette" $palette "spec" $spec) }}'
{{- end }}
    }
    Fzf        = @{
{{- range $role, $spec := .roles.fzf }}
      '{{ $role }}' = '{{ template "theme/spec" (dict "palette" $palette "spec" $spec) }}'
{{- end }}
    }
    # A list of `code=spec` strings, not a hashtable: eza's codes are case-sensitive (`gd` and
    # `Gd` differ) and PowerShell hashtable keys are not.
    Eza        = @(
{{- range $role, $spec := .roles.eza }}
      '{{ $role }}={{ template "theme/spec" (dict "palette" $palette "spec" $spec) }}'
{{- end }}
    )
  }
}
