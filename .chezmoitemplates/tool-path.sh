# Homebrew's bin and mise's tools (node for npx, ...) are on PATH only in a shell that ran
# `brew shellenv` and `mise activate` (.zshrc). chezmoi's PATH can lack them, such as on the apply
# that installs them; without this a tool would look missing and a run_onchange script would be
# recorded as done although it skipped.
[ -x /home/linuxbrew/.linuxbrew/bin/brew ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
command -v mise >/dev/null && eval "$(mise activate bash --shims)"
