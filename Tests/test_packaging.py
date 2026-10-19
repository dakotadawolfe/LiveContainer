import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('inspect_ipa', Path(__file__).parents[1] / 'scripts/inspect_ipa.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class PackagingTests(unittest.TestCase):
    def make_ipa(self, path, omit=None, extra=None):
        prefix = 'Payload/LiveContainer.app/'
        with zipfile.ZipFile(path, 'w') as z:
            z.writestr(prefix + 'Info.plist', plistlib.dumps({'CFBundleIdentifier': 'com.kdt.livecontainer', 'CFBundleExecutable': 'LiveContainer', 'LCUnifiedManager': True}))
            z.writestr(prefix + 'LiveContainer', b'test fixture')
            for name in module.REQUIRED + ['Frameworks/StikJIT.framework/StikJIT']:
                if name == omit: continue
                data = plistlib.dumps({'CFBundleIdentifier': 'com.kdt.livecontainer.' + name.split('/')[1]}) if name.endswith('Info.plist') else b'test fixture'
                z.writestr(prefix + name, data)
            if extra: z.writestr(extra, b'unsafe')

    def test_complete_bundle_is_structurally_valid_but_not_device_verified(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'combined.ipa'
            self.make_ipa(path)
            report = module.inspect(path)
            self.assertFalse(report['selfRefreshVerified'])
            self.assertFalse(report['deviceSigningVerified'])

    def test_every_required_component_is_enforced(self):
        with tempfile.TemporaryDirectory() as tmp:
            for missing in module.REQUIRED:
                with self.subTest(missing=missing):
                    path = Path(tmp) / 'incomplete.ipa'
                    self.make_ipa(path, omit=missing)
                    with self.assertRaises(ValueError): module.inspect(path)

    def test_path_traversal_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'unsafe.ipa'
            self.make_ipa(path, extra='../escape')
            with self.assertRaises(ValueError): module.inspect(path)

if __name__ == '__main__': unittest.main()
