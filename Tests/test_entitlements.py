import importlib.util
from pathlib import Path
import plistlib
import struct
import unittest

spec = importlib.util.spec_from_file_location('inspect_entitlements', Path(__file__).parents[1] / 'scripts/inspect_entitlements.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def executable(value):
    xml = plistlib.dumps(value)
    blob = struct.pack('>II', 0xfade7171, 8 + len(xml)) + xml
    signature = struct.pack('>IIIII', 0xfade0cc0, 20 + len(blob), 1, 5, 20) + blob
    header = struct.pack('<IIIIIIII', 0xfeedfacf, 0x100000c, 0, 2, 1, 16, 0, 0)
    return header + struct.pack('<IIII', 0x1d, 16, 48, len(signature)) + signature


class EntitlementTests(unittest.TestCase):
    def test_reads_embedded_requests(self):
        value = {'get-task-allow': True, 'keychain-access-groups': ['TEAM.shared']}
        self.assertEqual(value, module.entitlements(executable(value)))

    def test_rejects_truncated_and_invalid_offsets(self):
        data = executable({'get-task-allow': True})
        for count in [0, 31, 40, 49, len(data) - 1]:
            with self.subTest(length=count), self.assertRaises(ValueError):
                module.entitlements(data[:count])
        broken = bytearray(data)
        struct.pack_into('<I', broken, 40, len(data) + 100)
        with self.assertRaises(ValueError): module.entitlements(broken)

    def test_rejects_unsigned_executable(self):
        unsigned = struct.pack('<IIIIIIII', 0xfeedfacf, 0x100000c, 0, 2, 0, 0, 0, 0)
        with self.assertRaises(ValueError): module.entitlements(unsigned)


if __name__ == '__main__': unittest.main()
