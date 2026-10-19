"""Apply the bounded embedded-service additions to an exact upstream checkout."""
from pathlib import Path
import shutil
import sys

root = Path(sys.argv[1]).resolve()
project = Path(__file__).resolve().parents[1]
shutil.copy2(project / 'integration/SideStore/UnifiedManagerBridge.swift', root / 'SideStore/UnifiedManagerBridge.swift')

def replace(path, old, new):
    file = root / path
    text = file.read_text(encoding='utf-8')
    if new in text:
        return
    if text.count(old) != 1:
        raise RuntimeError(f'Upstream changed; review {path} before applying integration')
    file.write_text(text.replace(old, new), encoding='utf-8', newline='\n')

# Guard the final bundle even when an upstream source offers standalone LiveContainer.
replace('SideStore/Core/Operations/PipelineOperations/ResignAppOperation.swift',
        '        let fileURL = targetAppBundle.fileURL',
        '''        if targetAppBundle.isAltStoreApp,
           Bundle.Info.activeBundle.object(forInfoDictionaryKey: "LCUnifiedManager") as? Bool == true {
            try LCUnifiedManagerBridge.validateCombinedBundle(targetAppBundle.fileURL)
        }
        let fileURL = targetAppBundle.fileURL''')

# A missing cached host must never cause refresh to fetch a different source artifact.
replace('SideStore/Core/Operations/PipelineRunner.swift',
        '            context.targetAppBundle = ALTApplication(fileURL: app.fileURL)',
        '''            context.targetAppBundle = ALTApplication(fileURL: app.fileURL)
            if app.bundleIdentifier == StoreApp.altstoreAppID,
               Bundle.Info.activeBundle.object(forInfoDictionaryKey: "LCUnifiedManager") as? Bool == true,
               case .refresh = operation {
                try LCUnifiedManagerBridge.validateCombinedBundle(Bundle.Info.activeBundleURL)
                context.targetAppBundle = ALTApplication(fileURL: Bundle.Info.activeBundleURL)
            }''')
print('Embedded SideStore integration applied')
