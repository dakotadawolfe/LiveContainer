import SwiftUI

@MainActor
final class ContainerInstaller: ObservableObject {
    static let shared = ContainerInstaller()
    @Published var installOptions: [AppReplaceOption] = []
    @Published var installProgressPercentage: Float = 0
    let installReplaceAlert = AlertHelper<AppReplaceOption>()
    var installObserver: NSKeyValueObservation?
    var delegate: LCAppModelDelegate?
    var warning: String?
    var sharedModel: SharedModel { DataManager.shared.model }

    nonisolated func decompress(_ path: String, _ destination: String, _ progress: Progress) async -> Int32 {
        extract(path, destination, progress)
    }

    func install(_ url: URL, source installSource: URL?, download installDownload: URL?) async throws {
        warning = nil
        let fm = FileManager()
        let workspace = fm.temporaryDirectory.appendingPathComponent("Install-" + UUID().uuidString)
        try fm.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: workspace); installObserver = nil }
        try Task.checkCancellation()
        
        let installProgress = Progress.discreteProgress(totalUnitCount: 100)
        self.installProgressPercentage = 0.0
        self.installObserver = installProgress.observe(\.fractionCompleted) { p, v in
            DispatchQueue.main.async {
                self.installProgressPercentage = Float(p.fractionCompleted)
            }
        }
        let decompressProgress = Progress.discreteProgress(totalUnitCount: 100)
        installProgress.addChild(decompressProgress, withPendingUnitCount: 80)
        let payloadPath = workspace.appendingPathComponent("Payload")
        if fm.fileExists(atPath: payloadPath.path) {
            try fm.removeItem(at: payloadPath)
        }
        
        // decompress
        guard await decompress(url.path, workspace.path, decompressProgress) == 0 else {
            throw "lc.appList.urlFileIsNotIpaError".loc
        }

        let payloadContents = try fm.contentsOfDirectory(atPath: payloadPath.path)
        var appBundleName : String? = nil
        for fileName in payloadContents {
            if fileName.hasSuffix(".app") {
                appBundleName = fileName
                break
            }
        }
        guard let appBundleName = appBundleName else {
            throw "lc.appList.bundleNotFondError".loc
        }

        let appFolderPath = payloadPath.appendingPathComponent(appBundleName)
        
        guard let newAppInfo = LCAppInfo(bundlePath: appFolderPath.path) else {
            throw "lc.appList.infoPlistCannotReadError".loc
        }

        guard let bundleID = newAppInfo.bundleIdentifier(), !bundleID.isEmpty else {
            throw "This IPA has no application bundle identifier."
        }
        var appRelativePath = "\(bundleID.sanitizeNonACSII()).app"
        var outputFolder = LCPath.bundlePath.appendingPathComponent(appRelativePath)
        var appToReplace : LCAppModel? = nil
        // Folder exist! show alert for user to choose which bundle to replace
        var sameBundleIdApp = sharedModel.apps.filter { app in
            return app.appInfo.bundleIdentifier()! == newAppInfo.bundleIdentifier()
        }
        if sameBundleIdApp.count == 0 {
            sameBundleIdApp = sharedModel.hiddenApps.filter { app in
                return app.appInfo.bundleIdentifier()! == newAppInfo.bundleIdentifier()
            }
            
            // we found a hidden app, we need to authenticate before proceeding
            if sameBundleIdApp.count > 0 && !sharedModel.isHiddenAppUnlocked {
                guard try await LCUtils.authenticateUser() else { throw CancellationError() }
            }
            
        }
        
        if fm.fileExists(atPath: outputFolder.path) || sameBundleIdApp.count > 0 {
            appRelativePath = "\(bundleID.sanitizeNonACSII())_\(UUID().uuidString).app"
            
            self.installOptions = [AppReplaceOption(isReplace: false, nameOfFolderToInstall: appRelativePath)]
            
            for app in sameBundleIdApp {
                self.installOptions.append(AppReplaceOption(isReplace: true, nameOfFolderToInstall: app.appInfo.relativeBundlePath, appToReplace: app))
            }

            guard let installOptionChosen = await installReplaceAlert.open() else {
                // user cancelled
                throw CancellationError()
            }
            
            if let appToReplace = installOptionChosen.appToReplace, appToReplace.uiIsShared {
                outputFolder = LCPath.lcGroupBundlePath.appendingPathComponent(installOptionChosen.nameOfFolderToInstall)
            } else {
                outputFolder = LCPath.bundlePath.appendingPathComponent(installOptionChosen.nameOfFolderToInstall)
            }
            appRelativePath = installOptionChosen.nameOfFolderToInstall
            appToReplace = installOptionChosen.appToReplace

        }
        // Prepare the replacement completely before touching the installed bundle.
        let finalNewApp = LCAppInfo(bundlePath: appFolderPath.path)
        finalNewApp?.relativeBundlePath = appRelativePath
        
        guard let finalNewApp else {
            throw "lc.appList.appInfoInitError".loc
        }
        
        // patch and sign it
        var signError : String? = nil
        var signSuccess = false
        await withUnsafeContinuation({ c in
            if appToReplace?.uiDontSign ?? false || LCUtils.appGroupUserDefault.bool(forKey: "LCDontSignApp") {
                finalNewApp.dontSign = true
            }
            finalNewApp.patchExecAndSignIfNeed(completionHandler: { success, error in
                signError = error
                signSuccess = success
                c.resume()
            }, progressHandler: { signProgress in
                if let signProgress { installProgress.addChild(signProgress, withPendingUnitCount: 20) }
            }, forceSign: false)
        })
        
        guard signSuccess else { throw signError?.loc ?? "Signing the container app failed." }
        warning = signError?.loc

        if let appToReplace {
            // copy previous configration to new app
            finalNewApp.autoSaveDisabled = true
            finalNewApp.isLocked = appToReplace.appInfo.isLocked
            finalNewApp.isHidden = appToReplace.appInfo.isHidden
            finalNewApp.isJITNeeded = appToReplace.appInfo.isJITNeeded
            finalNewApp.isShared = appToReplace.appInfo.isShared
            finalNewApp.spoofSDKVersion = appToReplace.appInfo.spoofSDKVersion
            finalNewApp.doSymlinkInbox = appToReplace.appInfo.doSymlinkInbox
            finalNewApp.containerInfo = appToReplace.appInfo.containerInfo
            finalNewApp.tweakFolder = appToReplace.appInfo.tweakFolder
            finalNewApp.selectedLanguage = appToReplace.appInfo.selectedLanguage
            finalNewApp.dataUUID = appToReplace.appInfo.dataUUID
            finalNewApp.orientationLock = appToReplace.appInfo.orientationLock
            finalNewApp.dontInjectTweakLoader = appToReplace.appInfo.dontInjectTweakLoader
            finalNewApp.hideLiveContainer = appToReplace.appInfo.hideLiveContainer
            finalNewApp.dontLoadTweakLoader = appToReplace.appInfo.dontLoadTweakLoader
            finalNewApp.doUseLCBundleId = appToReplace.appInfo.doUseLCBundleId
            finalNewApp.fixFilePickerNew = appToReplace.appInfo.fixFilePickerNew
            finalNewApp.fixLocalNotification = appToReplace.appInfo.fixLocalNotification
            finalNewApp.lastLaunched = appToReplace.appInfo.lastLaunched
            finalNewApp.jitLaunchScriptJs = appToReplace.appInfo.jitLaunchScriptJs
            finalNewApp.multitaskSpecified = appToReplace.appInfo.multitaskSpecified
            finalNewApp.classicMode = appToReplace.appInfo.classicMode
            finalNewApp.autoSaveDisabled = false
            finalNewApp.save()
        } else {
            // enable SDK version spoof by defalut
            finalNewApp.spoofSDKVersion = true
        }
        finalNewApp.installationDate = Date.now
        try ContainerBundleCommit.install(prepared: appFolderPath, destination: outputFolder)
        guard let installedInfo = LCAppInfo(bundlePath: outputFolder.path) else { throw "Installed bundle could not be read." }
        installedInfo.relativeBundlePath = appRelativePath
        
        do {
            if let appToReplace {
                let newAppModel = LCAppModel(appInfo: installedInfo, delegate: self.delegate)
                
                if appToReplace.uiIsHidden {
                    sharedModel.hiddenApps.removeAll { $0 == appToReplace }
                    sharedModel.hiddenApps.append(newAppModel)
                } else {
                    sharedModel.apps.removeAll { $0 == appToReplace }
                    sharedModel.apps.append(newAppModel)
                }

            } else {
                let newAppModel = LCAppModel(appInfo: installedInfo, delegate: self.delegate)
                sharedModel.apps.append(newAppModel)
                
                // add url schemes
                if let urlSchemes = finalNewApp.urlSchemes(), urlSchemes.count > 0 {
                    UserDefaults.lcShared().mutableArrayValue(forKey: "LCGuestURLSchemes")
                        .addObjects(from: urlSchemes as! [Any])
                }
            }
        }
        do {
            try UnifiedInstallRecords.shared.record(bundleID: bundleID, source: installSource, download: installDownload, destination: .liveContainer)
        } catch {
            warning = "Installed, but source tracking could not be saved: \(error.localizedDescription)"
        }
    }
    
}
