# =============================================================================
# Functions
# =============================================================================

if ($IsInteractiveConsole) {

  function touch
  {
    Param(
      [Parameter(Mandatory=$true)]
      [string]$Path
    )

    if (Test-Path -LiteralPath $Path)
    {
      (Get-Item -Path $Path).LastWriteTime = Get-Date
    } else
    {
      New-Item -Type File -Path $Path
    }
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

  function atob
  {
    Param(
      [Parameter(Mandatory=$true)]
      [string]$InputString
    )
    return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($InputString))
  }

  function btoa
  {
    Param(
      [Parameter(Mandatory=$true)]
      [string]$InputString
    )
    return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($InputString))
  }
}
