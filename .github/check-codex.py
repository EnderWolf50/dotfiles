# /// script
# requires-python = ">=3.11"
# dependencies = ["tomlkit==0.15.1"]
# ///
"""Run with uv run --script .github/check-codex.py from the source root."""
import subprocess
from pathlib import Path
import tempfile
import tomllib
import unittest


def render(source, os_name="windows"):
    result = subprocess.run(
        ["chezmoi", "execute-template", "--source", ".", "--override-data",
         '{"chezmoi":{"os":"' + os_name + '"}}', "-f", source],
        capture_output=True, text=True, encoding="utf-8", check=True)
    return result.stdout


namespace = {"__name__": "codex_settings"}
exec(compile(render("dot_codex/sync-settings.py.tmpl"), "sync-settings.py", "exec"), namespace)
merge_config, sync = namespace["merge_config"], namespace["sync"]
LOCAL = '''# Keep my model and experimental provider notes.
model = "my-local-model" # keep this comment
model_reasoning_effort = "low"
project_doc_fallback_filenames = ["TEAM.md"]

[desktop]
appearanceTheme = "system"

[mcp_servers.local]
url = "https://example.invalid/mcp"

[mcp_servers.semble]
command = "old-uvx"
args = ["old"]
enabled = false
startup_timeout_sec = 120

[shell_environment_policy.set]
MY_LOCAL_ENV = "keep"
'''


class CodexSettingsTests(unittest.TestCase):
    def test_preserves_local_settings_comments_and_server_policy(self):
        result = merge_config(LOCAL)
        original, updated = tomllib.loads(LOCAL), tomllib.loads(result)
        for key in ("model", "model_reasoning_effort", "desktop"):
            self.assertEqual(updated[key], original[key])
        self.assertIn('# Keep my model and experimental provider notes.', result)
        self.assertIn('# keep this comment', result)
        self.assertEqual(updated["mcp_servers"]["local"], original["mcp_servers"]["local"])
        self.assertFalse(updated["mcp_servers"]["semble"]["enabled"])
        self.assertEqual(updated["mcp_servers"]["semble"]["startup_timeout_sec"], 120)
        self.assertEqual(updated["mcp_servers"]["semble"]["command"], "uvx")
        self.assertEqual(updated["mcp_servers"]["playwright"]["args"][-1], "--isolated")
        self.assertEqual(updated["project_doc_fallback_filenames"], ["TEAM.md", "CLAUDE.md"])
        self.assertEqual(updated["shell_environment_policy"]["set"]["MY_LOCAL_ENV"], "keep")
        self.assertEqual(result, merge_config(result))

    def test_new_config_and_transport_change(self):
        config = tomllib.loads(merge_config(""))
        self.assertEqual(config["project_doc_fallback_filenames"], ["CLAUDE.md"])
        result = tomllib.loads(merge_config('[mcp_servers.semble]\nurl = "https://old.invalid"\n'))
        self.assertNotIn("url", result["mcp_servers"]["semble"])
        self.assertEqual(result["mcp_servers"]["semble"]["command"], "uvx")

    def test_backup_and_idempotent_write(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.toml"
            path.write_bytes(LOCAL.encode("utf-8"))
            self.assertTrue(sync(path))
            backups = list(path.parent.glob("config.toml.bak-*"))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_bytes(), LOCAL.encode("utf-8"))
            modified = path.stat().st_mtime_ns
            self.assertFalse(sync(path))
            self.assertEqual(path.stat().st_mtime_ns, modified)
            self.assertEqual(len(list(path.parent.glob("config.toml.bak-*"))), 1)

    def test_invalid_config_stays_untouched(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.toml"
            path.write_text("[broken", encoding="utf-8")
            with self.assertRaises(Exception):
                sync(path)
            self.assertEqual(path.read_text(encoding="utf-8"), "[broken")
            self.assertEqual(list(path.parent.glob("config.toml.bak-*")), [])

    def test_instructions_on_both_operating_systems(self):
        for os_name in ("windows", "linux"):
            claude = render("dot_claude/CLAUDE.md.tmpl", os_name)
            codex = render("dot_codex/AGENTS.md.tmpl", os_name)
            for text in (claude, codex):
                self.assertIn("Always reply in 繁體中文", text)
                self.assertIn("mcp__semble__search", text)
                self.assertIn("Package manager: pnpm", text)
            self.assertIn("<name>.patch/SKILL.md", codex)
            self.assertNotIn("`haiku`", codex)
            self.assertNotIn("run_in_background", codex)
            self.assertNotIn("Edit tool", codex)
            self.assertIn("`haiku`", claude)
            self.assertEqual("## Windows shell" in codex, os_name == "windows")


if __name__ == "__main__":
    unittest.main()
