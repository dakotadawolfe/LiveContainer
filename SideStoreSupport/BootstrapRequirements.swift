import Foundation

/// Checks installation prerequisites, not successful signing or database migration.
public enum BootstrapRequirements {
    public static let components = [
        "Frameworks/SideStoreApp.framework/SideStore",
        "Frameworks/SideStoreSupport.framework/SideStoreSupport",
        "Frameworks/StikJITHeadless.framework/StikJITHeadless",
        "PlugIns/LiveProcess.appex/Info.plist",
        "PlugIns/LiveWidgetExtension.appex/Info.plist",
        "PlugIns/LaunchAppExtension.appex/Info.plist",
        "PlugIns/ShareExtension.appex/Info.plist",
        "Metadata.appintents/extract.actionsdata"
    ]

    public static func problem(bundleURL: URL, sharedGroupAccessible: Bool) -> String? {
        let missing = components.filter {
            !FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent($0).path)
        }
        var reasons: [String] = []
        if !missing.isEmpty {
            reasons.append("This installation is missing required components:\n" + missing.joined(separator: "\n"))
        }
        if !sharedGroupAccessible {
            reasons.append("iOS has not provided access to the shared App Group container. Embedded SideStore cannot open its database or save your Apple account.")
        }
        guard !reasons.isEmpty else { return nil }
        return reasons.joined(separator: "\n\n") + "\n\nBack up guest data before reinstalling the complete combined IPA. Keep all extensions and App Group entitlements. For Impactor, select Only Register Main Bundle. Do not choose Remove and Install or reset SideStore's database. Once embedded SideStore opens, install the full combined IPA there before testing self-refresh."
    }
}
