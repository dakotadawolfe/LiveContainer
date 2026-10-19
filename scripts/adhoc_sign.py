"""Preserve entitlement requests for the bootstrap signer, without developer credentials."""
from pathlib import Path
import plistlib
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
host = root / 'Payload/LiveContainer.app'
templates = {'LiveContainer.app': 'entitlements.xml', 'LiveProcess.appex': 'LiveProcess/LiveProcess.entitlements',
             'LaunchAppExtension.appex': 'LaunchAppExtension/LaunchAppExtension.entitlements',
             'ShareExtension.appex': 'ShareExtension/ShareExtension.entitlements',
             'LiveWidgetExtension.appex': '.github/sidelc/LiveWidgetExtension_adhoc.xml'}

def expand(value, bundle_id):
    replacements = {'$(DEVELOPMENT_TEAM)': 'AAAAA11111', '$(PRODUCT_BUNDLE_IDENTIFIER)': bundle_id,
                    '$(AppIdentifierPrefix)': 'AAAAA11111.', '$(APP_GROUP_SIDESTORE)': 'group.com.SideStore.SideStore',
                    '$(APP_GROUP_ALTSTORE)': 'group.com.rileytestut.AltStore'}
    if isinstance(value, str):
        for key, replacement in replacements.items(): value = value.replace(key, replacement)
        if '$(' in value: raise ValueError('Unresolved entitlement build variable')
        return value
    if isinstance(value, list): return [expand(item, bundle_id) for item in value]
    if isinstance(value, dict): return {key: expand(item, bundle_id) for key, item in value.items()}
    return value

for bundle in list((host / 'PlugIns').glob('*.appex')) + [host]:
    info = plistlib.loads((bundle / 'Info.plist').read_bytes())
    template = templates[bundle.name]
    entitlements = expand(plistlib.loads((root / template).read_bytes()), info['CFBundleIdentifier'])
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / 'entitlements.plist'
        path.write_bytes(plistlib.dumps(entitlements))
        subprocess.run(['ldid', '-S' + str(path), str(bundle / info['CFBundleExecutable'])], check=True)
