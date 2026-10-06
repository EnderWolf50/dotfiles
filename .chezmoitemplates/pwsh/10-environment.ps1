# =============================================================================
# Environment
# =============================================================================

if ($IsInteractiveConsole) {
  # Native tools such as eza print UTF-8 (icons, tree lines), but the console defaults to
  # cp437 on this machine, which garbles them.
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

  $Env:EDITOR = "nvim"

  # herdr passes OSC 8 links through, but Claude Code only emits them for terminals on its own list,
  # which herdr is not on yet (herdr#4748). Drop this once Claude Code knows herdr.
  if ($Env:TERM_PROGRAM -eq 'herdr') { $Env:FORCE_HYPERLINK = '1' }
}
