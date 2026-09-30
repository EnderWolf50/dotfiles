# =============================================================================
# Aliases
# =============================================================================

if ($IsInteractiveConsole) {
  # Not enabled: `Import-Module git-aliases -DisableNameChecking` (oh-my-zsh style git aliases).

  Set-SafeAlias open ii
  Set-SafeAlias vim nvim
  Set-SafeAlias lg lazygit
  Set-SafeAlias cat bat
  Set-SafeAlias cx codex
  Set-SafeAlias cc claude
  Set-SafeAlias oc opencode
  Set-SafeAlias hr herdr
}
