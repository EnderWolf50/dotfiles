"""Render every target with `chezmoi archive` and syntax-check the output.

Run from the repo root: `python .github/check.py`. lefthook runs it before each commit and CI runs it
on Linux, so both OS branches of the templates get rendered. A checker whose program is missing
(zsh on Windows) is skipped.
"""
import io, json, os, shutil, subprocess, sys, tarfile, tempfile, tomllib

PS_PARSE = (
    "$e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile($env:CHECK_FILE, [ref]$null, [ref]$e); "
    "$e | ForEach-Object { $_.ToString() }; exit [int]($e.Count -gt 0)"
)
JSONC = {".neoconf.json"}  # JSON with comments, read by neoconf.nvim


def run(*cmd, path):
    if not shutil.which(cmd[0]):
        return None
    r = subprocess.run(cmd, capture_output=True, text=True, env={**os.environ, "CHECK_FILE": path})
    return None if r.returncode == 0 else (r.stdout + r.stderr).strip()


def check(path, name):
    base = os.path.basename(name)
    if base.endswith(".ps1"):
        return run("pwsh", "-NoProfile", "-NonInteractive", "-Command", PS_PARSE, path=path)
    if base.endswith(".sh"):
        return run("bash", "-n", path, path=path)
    if base in {".zshrc", ".zprofile", ".zimrc"}:
        return run("zsh", "-n", path, path=path)
    if base.endswith(".js"):
        return run("node", "--check", path, path=path)
    try:
        if base.endswith(".json") and base not in JSONC:
            json.load(open(path, encoding="utf-8"))
        elif base.endswith(".toml"):
            tomllib.load(open(path, "rb"))
    except ValueError as e:
        return str(e)


tar = subprocess.run(["chezmoi", "archive", "--source", "."], capture_output=True, stdin=subprocess.DEVNULL)
if tar.returncode:
    sys.exit(tar.stderr.decode())

failed = 0
with tempfile.TemporaryDirectory() as tmp, tarfile.open(fileobj=io.BytesIO(tar.stdout)) as t:
    for m in t.getmembers():
        if not m.isfile():
            continue
        path = os.path.join(tmp, os.path.basename(m.name))  # checked right away, so a reused name is fine
        with open(path, "wb") as f:
            f.write(t.extractfile(m).read())
        if err := check(path, m.name):
            failed += 1
            print(f"{m.name}: {err}")

# modify_settings.json `append`: the machine's own list entries stay, the repo's are added once.
local = {"permissions": {"ask": ["Bash(rm:*)", "Bash(tinyfish agent:*)"]}}
r = subprocess.run(["chezmoi", "execute-template", "--with-stdin", "-f", "dot_claude/modify_settings.json"],
                   input=json.dumps(local), capture_output=True, text=True, encoding="utf-8")
ask = json.loads(r.stdout or "{}").get("permissions", {}).get("ask", [])
if (r.returncode or "Bash(rm:*)" not in ask or ask.count("Bash(tinyfish agent:*)") != 1
        or "PowerShell(tinyfish browser:*)" not in ask):
    failed += 1
    print(f"dot_claude/modify_settings.json: append lost or duplicated permissions.ask entries: {ask or r.stderr.strip()}")
sys.exit(failed and 1)
