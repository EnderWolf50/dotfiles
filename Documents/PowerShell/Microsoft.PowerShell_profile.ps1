
#
# prerequisites
#

# modules:
# posh-git (https://github.com/dahlbyk/posh-git)
# oh-my-posh (https://github.com/JanDeDobbeleer/oh-my-posh)
# starship (https://starship.rs/)
# terminal-icons (https://github.com/devblackops/Terminal-Icons)
# cd-extras (https://github.com/nickcox/cd-extras)
# gsudo (https://github.com/gerardog/gsudo)
# psreadline (https://github.com/PowerShell/PSReadLine)
# psfzf (https://github.com/kelleyma49/PSFzf)
#
# tools:
# fzf (https://github.com/junegunn/fzf)
# fnm (https://github.com/Schniz/fnm)
# zoxide (https://github.com/ajeetdsouza/zoxide)
#
# aliases:
# git-aliases (https://github.com/gluons/powershell-git-aliases)

#
# ui
#

function Test-InteractiveConsole {
  $Host.Name -eq 'ConsoleHost' -and
    -not [Console]::IsInputRedirected -and
    -not [Console]::IsOutputRedirected -and
    -not [Console]::IsErrorRedirected
}

$IsInteractiveConsole = Test-InteractiveConsole

# posh-git
# Import-Module posh-git

# oh-my-posh
# oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\star.omp.json" | Invoke-Expression
# $env:POSH_GIT_ENABLED = $true

# starship
if ($IsInteractiveConsole) {
  Invoke-Expression (&starship init powershell)
}

# terminal-icons
# Terminal-Icons rewrites its Clixml cache on every import; serialize it so
# shells started together (e.g. herdr panes) don't read a half-written file.
if ($IsInteractiveConsole) {
  $tiMutex = [System.Threading.Mutex]::new($false, 'Local\TerminalIconsImport')
  try {
    try { $null = $tiMutex.WaitOne(10000) } catch [System.Threading.AbandonedMutexException] { }
    Import-Module Terminal-Icons
  } finally {
    try { $tiMutex.ReleaseMutex() } catch { }
    $tiMutex.Dispose()
  }
}

#
# utils
#

# cd-extras
# Import-Module cd-extras
# gsudo
# Import-Module gsudoModule

# psreadline
# Import-Module PSReadLine
# Set-PSReadLineOption -PredictionSource History
# Set-PSReadLineOption -PredictionViewStyle ListView
# Set-PSReadLineOption -EditMode Windows
# Set-PSReadLineOption -BellStyle None

if ($IsInteractiveConsole) {
  $env:CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense' # optional
  Set-PSReadLineOption -Colors @{ "Selection" = "`e[7m" }
  Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
  carapace _carapace | Out-String | Invoke-Expression
}

# psfzf
if ($IsInteractiveConsole) {
  Import-Module PSFzf
  Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' `
    -PSReadlineChordReverseHistory 'Ctrl+r'

  # Tab is bound to MenuComplete for carapace above; rebinding it here would override that
  # Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
}

#
# aliases & Envs & functions
#
if ($IsInteractiveConsole) {

  # Import-Module git-aliases -DisableNameChecking

  Set-Alias open ii
  Set-Alias grep rg
  Set-Alias vim nvim
  Set-Alias lg lazygit
  Set-Alias cat bat
  Set-Alias cc claude
  Set-Alias oc opencode
  Set-Alias oc2 opencode2
  Set-Alias hr herdr

  function crm {
    Set-Location "D:\CRM\"
  }

  $Env:EDITOR = "nvim"

  function tree
  {
    param (
      [Parameter(Mandatory=$false)]
      [string]$Path = ".",

      [Parameter(Mandatory=$false)]
      [int]$Depth = -1, # -1 for unlimited depth
          
      [Parameter(Mandatory=$false)]
      [switch]$FoldersOnly, # Only show folders

      [Parameter(Mandatory=$false)]
      [string[]]$Exclude # Patterns to exclude (e.g., "*.log", "node_modules")
    )

    # ANSI escape codes for colors
    $ResetColor = "`e[0m"
    $FolderColor = "`e[34m" # Blue
    $FileColor = "`e[37m"  # White/Light Gray

    function Get-ChildTreeRecursive
    {
      param (
        [string]$CurrentPath,
        [string]$Prefix,
        [int]$CurrentDepth
      )

      if ($CurrentDepth -eq 0 -and $Depth -ne -1)
      {
        return
      }

      $items = Get-ChildItem -LiteralPath $CurrentPath | Sort-Object PSIsContainer, Name

      # Apply custom exclusion logic
      if ($Exclude)
      {
        $filteredItems = @()
        foreach ($item in $items)
        {
          $isExcluded = $false
          foreach ($pattern in $Exclude)
          {
            if ($item.Name -like $pattern)
            {
              $isExcluded = $true
              break # Found a match, no need to check other patterns for this item
            }
          }
          if (-not $isExcluded)
          {
            $filteredItems += $item
          }
        }
        $items = $filteredItems
      }

      for ($i = 0; $i -lt $items.Count; $i++)
      {
        $item = $items[$i]
        $isLastItem = ($i -eq ($items.Count - 1))
        $newPrefix = if ($isLastItem)
        { "$Prefix`    " 
        } else
        { "$Prefix│   " 
        }
        $itemPrefix = if ($isLastItem)
        { "└── " 
        } else
        { "├── " 
        }

        if ($item.PSIsContainer)
        {
          # Display folder in blue and then recurse
          Write-Host "$Prefix$itemPrefix$FolderColor$($item.Name)$ResetColor"
          Get-ChildTreeRecursive -CurrentPath $item.FullName -Prefix $newPrefix -CurrentDepth ($CurrentDepth - 1)
        } elseif (-not $FoldersOnly)
        {
          # Display file in default color
          Write-Host "$Prefix$itemPrefix$FileColor$($item.Name)$ResetColor"
        }
      }
    }

    # Print the base path
    Write-Host (Convert-Path $Path)
    # Start the recursive tree generation
    Get-ChildTreeRecursive -CurrentPath (Convert-Path $Path) -Prefix "" -CurrentDepth $Depth
  }

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

#
# tools
#

# mise
mise activate pwsh | Out-String | Invoke-Expression

# zoxide
if ($IsInteractiveConsole) {
  Invoke-Expression (& { (zoxide init powershell | Out-String) })

    function zz {
        param(
            [Parameter(ValueFromRemainingArguments=$true)]
            [string[]]$Query
        )

        zoxide query -i @Query
    }
}


