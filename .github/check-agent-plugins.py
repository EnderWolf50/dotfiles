"""Test declared plugin reconciliation and generated agent definitions without installing plugins."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest
from unittest.mock import patch


def render(source, stdin=None):
    command = ['chezmoi', 'execute-template', '--source', '.', '-f', source]
    if stdin is not None:
        command.append('--with-stdin')
    return subprocess.run(command, input=stdin, text=True, capture_output=True, encoding='utf-8', check=True).stdout


namespace = {'__name__': 'test_agent_plugins'}
exec(compile(render('dot_agents/sync-plugins.py.tmpl'), 'sync-plugins.py', 'exec'), namespace)
plan, catalog = namespace['plan'], namespace['CATALOG']


class AgentPlugins(unittest.TestCase):
    def test_disabled_uninstalled_codex_plugin_stays_absent(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            config = home / '.codex/config.toml'
            config.parent.mkdir()
            config.write_text('[plugins."guards@enderwolf50"]\nenabled = false\n')
            previous = namespace['output']
            namespace['output'] = lambda command: {'installed': []} if command[2] == 'list' else {'marketplaces': []}
            try:
                with patch.dict(os.environ, {'CODEX_HOME': str(config.parent)}):
                    installed, markets = namespace['snapshot']('codex', home)
                self.assertFalse(installed['guards@enderwolf50'])
                self.assertNotIn(['codex', 'plugin', 'add', 'guards@enderwolf50'], plan('codex', installed, markets))
            finally:
                namespace['output'] = previous

    def test_missing_plugins_and_sparse_flags(self):
        commands = plan('codex', {}, set())
        self.assertEqual(sum(c[1:4] == ['plugin', 'marketplace', 'add'] for c in commands), 3)
        self.assertEqual(sum(c[1:3] == ['plugin', 'add'] for c in commands), 4)
        tempad = next(c for c in commands if c[4:5] == ['ecomfe/tempad-dev'])
        self.assertEqual(tempad.count('--sparse'), 2)
        cc = plan('claude', {}, set())
        tempad = next(c for c in cc if c[4:5] == ['ecomfe/tempad-dev'])
        self.assertEqual(tempad.count('--sparse'), 1)
        self.assertIn('--scope', cc[-1])

    def test_repeated_sync_and_disabled_choices(self):
        installed = {entry['id']: False for entry in catalog['plugins']}
        markets = set(catalog['marketplaces'])
        for host in ('claude', 'codex'):
            self.assertEqual(plan(host, installed, markets), [])
            commands = plan(host, installed, markets, update=True)
            self.assertTrue(commands)
            self.assertTrue(all(c[2] == 'marketplace' for c in commands))

    def test_no_removal_or_unrelated_updates(self):
        commands = plan('codex', {'unrelated@local': True}, {'local'})
        self.assertFalse(any('remove' in c or 'unrelated@local' in c for c in commands))

    def test_changed_source_re_registers_and_keeps_disabled_plugin(self):
        entry = catalog['marketplaces']['enderwolf50']
        markets = {name: None for name in catalog['marketplaces']}
        markets['enderwolf50'] = {'source_type': 'git', 'source': 'https://github.com/' + entry['source'] + '.git', 'ref': 'old'}
        installed = {entry['id']: True for entry in catalog['plugins']}
        installed['guards@enderwolf50'] = False
        commands = plan('codex', installed, markets)
        self.assertEqual(commands[0], ['codex', 'plugin', 'marketplace', 'remove', 'enderwolf50'])
        self.assertIn(entry['codex_ref'], commands[1])
        self.assertNotIn(['codex', 'plugin', 'add', 'guards@enderwolf50'], commands)
        self.assertIn(['codex', 'plugin', 'add', 'skill-patches@enderwolf50'], commands)

    def test_claude_catalog_migration_preserves_disabled(self):
        original = {'enabledPlugins': {'ponytail@ponytail': False, 'local@local': True}}
        rendered = json.loads(render('dot_claude/modify_settings.json', json.dumps(original)))
        self.assertFalse(rendered['enabledPlugins']['ponytail@ponytail'])
        self.assertTrue(rendered['enabledPlugins']['local@local'])
        self.assertTrue(rendered['enabledPlugins']['guards@enderwolf50'])
        self.assertEqual(rendered['extraKnownMarketplaces']['tempad-dev']['source']['sparsePaths'],
                         catalog['marketplaces']['tempad-dev']['claude_sparse'])

    def test_agents_share_body_and_inherit_model(self):
        for name in ('code-reviewer', 'implementer', 'researcher', 'retro-analyst'):
            with self.subTest(name=name):
                config = tomllib.loads(render(f'dot_codex/agents/{name}.toml.tmpl'))
                self.assertEqual(config['name'], name)
                self.assertIn('Done:', config['developer_instructions'])
                self.assertNotIn('model', config)
                self.assertNotIn('sandbox_mode', config)
                self.assertIn(config['model_reasoning_effort'], ('low', 'medium', 'high'))
                if name == 'implementer':
                    self.assertIn('Load the tdd skill', config['developer_instructions'])


if __name__ == '__main__':
    unittest.main()
