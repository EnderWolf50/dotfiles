# =============================================================================
# Environment
# =============================================================================

if ($IsInteractiveConsole) {
  # Native tools such as eza print UTF-8 (icons, tree lines), but the console defaults to
  # cp437 on this machine, which garbles them.
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

  $Env:EDITOR = "nvim"
}
