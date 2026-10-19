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

# Authentication must not start while database startup is still pending or has failed.
# Keep this outside the authentication catch, which can sign out and write account state.
replace('SideStore/Core/Operations/StandaloneOperations/SignInOperation.swift',
        '        try await super.executePreconditionCheck(parentProgress: parentProgress)\n\n        do {',
        '''        try await super.executePreconditionCheck(parentProgress: parentProgress)
        try await DatabaseManager.shared.start()

        do {''')
replace('SideStore/Core/Auth/AuthManager.swift',
        '''    ) async throws -> SignInResult {
        let dbBackgroundContext''',
        '''    ) async throws -> SignInResult {
        try await DatabaseManager.shared.start()
        let dbBackgroundContext''')

# Backgrounding the startup-error screen also used to save into an unloaded store.
replace('AltStore/Core/Model/DatabaseManager/DatabaseManager.swift',
        '''    public func purgeLoggedErrors(before date: Date? = nil) async throws
    {
        try await self.persistentContainer.performBackgroundTask''',
        '''    public func purgeLoggedErrors(before date: Date? = nil) async throws
    {
        guard self.isStarted else { return }
        try await self.persistentContainer.performBackgroundTask''')
replace('AltStore/Managing Apps/AppManager.swift',
        '''    func log(_ error: Error, operation: LoggedError.Operation, app: AppProtocol)
    {
        switch error''',
        '''    func log(_ error: Error, operation: LoggedError.Operation, app: AppProtocol)
    {
        guard DatabaseManager.shared.isStarted else {
            debugLog("[AppManager] Database unavailable; skipped persistent error logging.")
            return
        }
        switch error''')
replace('AltStore/Core/Model/DatabaseManager/PersistentContainer.swift',
        'Unable to access the shared App Group container. Refusing to create or use a private sandbox fallback database.',
        'iOS did not provide access to the shared App Group database. Apple ID sign-in cannot continue. Back up guest data, then reinstall the complete combined IPA with a supported installer that preserves App Groups and all extensions. Do not select Remove App Extensions or reset the database. Impactor: select Only Register Main Bundle. A private database cannot replace the shared store used by refresh and widgets.')

replace('SideStore/Core/Operations/StandaloneOperations/BackgroundRefreshAppsOperation.swift',
        '            group.beginInstallationHandler = { [weak self] (installedApp) in',
        '''            group.beginInstallationHandler = { [weak self] (installedApp) in
                if Bundle.Info.activeBundle.object(forInfoDictionaryKey: "LCUnifiedManager") as? Bool == true {
                    return // Installation starting is not a successful refresh.
                }''')
replace('SideStore/Core/Operations/StandaloneOperations/BackgroundRefreshAppsOperation.swift',
        'content.title = NSLocalizedString("Refreshed Apps", comment: "")',
        'content.title = NSLocalizedString("Refresh operation returned", comment: "")')
replace('SideStore/Core/Operations/StandaloneOperations/BackgroundRefreshAppsOperation.swift',
        'content.body = NSLocalizedString("All apps have been refreshed.", comment: "")',
        'content.body = NSLocalizedString("Open the manager to verify installed provisioning and any pending self-refresh.", comment: "")')
replace('AltStore/Intents/App Intents/RefreshAllAppsIntent.swift',
        'return .result(dialog: "All apps have been refreshed.")',
        'return .result(dialog: "Refresh returned. Open the manager to verify installed provisioning.")')
