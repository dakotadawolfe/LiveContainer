"""Verify combined IPA structure. This does not assert device signing or installation."""
import hashlib
import json
import plistlib
import sys
import zipfile
from pathlib import Path, PurePosixPath

REQUIRED = [
    'Frameworks/SideStoreApp.framework/SideStore',
    'Frameworks/SideStoreSupport.framework/SideStoreSupport',
    'Frameworks/StikJITHeadless.framework/StikJITHeadless',
    'PlugIns/LiveProcess.appex/Info.plist',
    'PlugIns/LiveWidgetExtension.appex/Info.plist',
    'Metadata.appintents/extract.actionsdata',
]

def inspect(path):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(set(names)) != len(names):
            raise ValueError('Duplicate archive entries')
        for name in names:
            p = PurePosixPath(name)
            if p.is_absolute() or '..' in p.parts or '\\' in name:
                raise ValueError('Unsafe archive path')
        hosts = [n for n in names if n.startswith('Payload/') and n.count('/') == 2 and n.endswith('.app/Info.plist')]
        if len(hosts) != 1:
            raise ValueError('Expected exactly one host application')
        host = hosts[0].removesuffix('Info.plist')
        info = plistlib.loads(archive.read(host + 'Info.plist'))
        for part in REQUIRED:
            if host + part not in names:
                raise ValueError('Missing combined component: ' + part)
        if not any(n.endswith('/StikJIT.framework/StikJIT') for n in names):
            raise ValueError('Missing StikJIT runtime')
        if not info.get('LCUnifiedManager'):
            raise ValueError('Missing manager marker')
        if host + info['CFBundleExecutable'] not in names:
            raise ValueError('Missing host executable')
        for n in names:
            if n.startswith(host + 'PlugIns/') and n.count('/') == 4 and n.endswith('/Info.plist'):
                extension = plistlib.loads(archive.read(n))
                if not extension['CFBundleIdentifier'].startswith(info['CFBundleIdentifier'] + '.'):
                    raise ValueError('Extension identifier does not belong to host')
        return {'sha256': hashlib.sha256(Path(path).read_bytes()).hexdigest(), 'bundleID': info['CFBundleIdentifier'],
                'sourceCommit': info.get('LCUnifiedBuildCommit'),
                'requiredComponents': REQUIRED, 'entries': len(names), 'deviceSigningVerified': False,
                'selfRefreshVerified': False}

if __name__ == '__main__':
    print(json.dumps(inspect(sys.argv[1]), indent=2))
