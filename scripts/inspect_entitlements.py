"""Inspect entitlement requests in a thin ARM64 IPA; not signature or provisioning verification."""
import json
import plistlib
import struct
import sys
import zipfile


def entitlements(binary):
    if len(binary) < 32 or binary[:4] != b'\xcf\xfa\xed\xfe':
        raise ValueError('Expected a thin 64-bit Mach-O executable')
    if struct.unpack_from('<I', binary, 4)[0] != 0x100000c:
        raise ValueError('Expected an ARM64 executable')
    commands, size = struct.unpack_from('<II', binary, 16)
    end = 32 + size
    if end > len(binary):
        raise ValueError('Truncated load commands')
    cursor = 32
    for _ in range(commands):
        if cursor + 8 > end:
            raise ValueError('Truncated load command')
        command, length = struct.unpack_from('<II', binary, cursor)
        if length < 8 or cursor + length > end:
            raise ValueError('Invalid load command length')
        if command == 0x1d:  # LC_CODE_SIGNATURE
            if length < 16:
                raise ValueError('Truncated signature command')
            offset, count = struct.unpack_from('<II', binary, cursor + 8)
            if offset + count > len(binary) or count < 12:
                raise ValueError('Truncated signature')
            signature = binary[offset:offset + count]
            magic, total, entries = struct.unpack_from('>III', signature)
            if magic != 0xfade0cc0 or total > count or 12 + entries * 8 > total:
                raise ValueError('Invalid code-signature container')
            for index in range(entries):
                slot, location = struct.unpack_from('>II', signature, 12 + index * 8)
                if slot != 5:  # CSSLOT_ENTITLEMENTS
                    continue
                if location + 8 > total:
                    raise ValueError('Truncated entitlement header')
                marker, length = struct.unpack_from('>II', signature, location)
                if marker != 0xfade7171 or length < 8 or location + length > total:
                    raise ValueError('Invalid entitlement blob')
                value = plistlib.loads(signature[location + 8:location + length].rstrip(b'\0'))
                if not isinstance(value, dict):
                    raise ValueError('Entitlements must be a dictionary')
                return value
            raise ValueError('No XML entitlement request in signature')
        cursor += length
    raise ValueError('No code-signature command')


def inspect(path):
    reports = []
    with zipfile.ZipFile(path) as archive:
        infos = [name for name in archive.namelist() if name.startswith('Payload/') and
                 (name.count('/') == 2 or ('/PlugIns/' in name and name.count('/') == 4)) and
                 name.endswith('/Info.plist')]
        for name in infos:
            info = plistlib.loads(archive.read(name))
            folder = name.removesuffix('Info.plist')
            requests = entitlements(archive.read(folder + info['CFBundleExecutable']))
            groups = requests.get('com.apple.security.application-groups', [])
            if 'group.com.SideStore.SideStore' not in groups:
                raise ValueError('Missing SideStore App Group request: ' + name)
            jit_process = name.count('/') == 2 or '/LiveProcess.appex/' in name
            if jit_process and requests.get('get-task-allow') is not True:
                raise ValueError('Missing debugger entitlement request: ' + name)
            if jit_process and not requests.get('keychain-access-groups'):
                raise ValueError('Missing keychain group requests: ' + name)
            reports.append({'bundleID': info['CFBundleIdentifier'], 'debuggerRequested': requests.get('get-task-allow', False),
                            'appGroupRequests': groups, 'keychainGroupCount': len(requests.get('keychain-access-groups', []))})
    if not reports:
        raise ValueError('No app bundles found')
    return {'entitlementRequests': reports, 'developerProvisioningVerified': False,
            'note': 'Ad-hoc entitlement requests only. The installer must obtain matching developer profiles.'}


if __name__ == '__main__':
    print(json.dumps(inspect(sys.argv[1]), indent=2))
