# =============================================================================
# Aliases
# =============================================================================
# An alias resolves its target when it is used, not when it is set, so tools that reach
# PATH later in the profile (mise) still work. Only aliases that shadow a built-in check
# first: without bat or nvim, `cat` and `vim` keep their default meaning.

if ($IsInteractiveConsole) {
  Set-Alias open ii
  if (has bat) { Set-Alias cat bat }
  if (has nvim) { Set-Alias vim nvim }
  Set-Alias lg lazygit
  Set-Alias cm chezmoi
  Set-Alias cx codex
  Set-Alias cc claude
  Set-Alias oc opencode
  Set-Alias hr herdr
}
