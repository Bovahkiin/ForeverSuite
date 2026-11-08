"""Release preflight cases: no network, git changes or publishing."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

script = Path(__file__).with_name('build_github_release.py')
spec = importlib.util.spec_from_file_location('release_builder', script)
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class ReleaseChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'Core').mkdir()
        self.write('ForeverSuite.toc', '## Version: 0.8.10\nCore/Init.lua\n')
        self.write('Core/Init.lua', 'FS.version = "0.8.10"\n')
        self.write('CHANGELOG.md', '# 0.8.10 - 2026-11-08\n\n- Current fix.\n\n# 0.8.9 - 2026-11-08\n\n- Earlier fix.\n')

    def write(self, name, value):
        (self.root / name).write_text(value, encoding='utf-8')

    def test_current_notes_only(self):
        version, notes = builder.metadata(self.root)
        self.assertEqual(version, '0.8.10')
        self.assertIn('Current fix', notes)
        self.assertNotIn('Earlier fix', notes)

    def test_mismatched_version_stops_release(self):
        self.write('Core/Init.lua', 'FS.version = "0.8.9"')
        with self.assertRaises(ValueError): builder.metadata(self.root)

    def test_missing_current_notes_stops_release(self):
        self.write('CHANGELOG.md', '# 0.8.9 - 2026-11-08\n\n- Earlier.\n')
        with self.assertRaises(ValueError): builder.metadata(self.root)

    def test_empty_notes_stops_release(self):
        self.write('CHANGELOG.md', '# 0.8.10 - 2026-11-08\n\n# 0.8.9 - 2026-11-08\n\n- Earlier.\n')
        with self.assertRaises(ValueError): builder.metadata(self.root)

    def test_unsafe_source_path_stops_release(self):
        self.write('ForeverSuite.toc', '## Version: 0.8.10\n../private.lua\n')
        with self.assertRaises(ValueError): builder.metadata(self.root)

    def test_missing_source_stops_release(self):
        (self.root / 'Core/Init.lua').unlink()
        with self.assertRaises(FileNotFoundError): builder.metadata(self.root)


if __name__ == '__main__':
    unittest.main()
