# Windows shell

The Bash tool runs Git Bash on Windows, beside Node and pwsh. Each item is a place where a value crossing between them changes on the way.

- **Path arguments**: Git Bash rewrites `/Foo`-style arguments into Windows paths; prefix `MSYS_NO_PATHCONV=1` (adb, `git show rev:path`, URL paths in env vars).
- **Two `/tmp` folders**: Node resolves `/tmp` to `D:\tmp` (the current drive), Git Bash to its own temp folder. A file one writes to `/tmp` and the other reads is a different file, possibly a stale one: pass an absolute Windows path (`cygpath -m`) or a `mktemp` path between them.
- **Line ends**: scoop `jq` and pwsh output end lines in `\r`; pipe through `tr -d '\r'` before comparing.
- **Console encoding**: a script without the profile (chezmoi scripts, `pwsh -NoProfile`) decodes a native command's output with the console code page, which garbles UTF-8 (CJK, `—`): set `[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)` before capturing it.
- **pwsh arguments**: `pwsh -Command '<script>' <args>` drops the trailing args (no `$args`): pass values through env vars, or write the script to a file and use `-File`.
