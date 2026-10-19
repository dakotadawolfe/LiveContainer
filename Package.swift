// swift-tools-version: 5.9
import PackageDescription

let package = Package(name: "UnifiedManagerRules", products: [], targets: [
    .target(name: "RefreshRules", path: "SideStoreSupport", sources: ["RefreshRules.swift", "BootstrapRequirements.swift"]),
    .testTarget(name: "RefreshRulesTests", dependencies: ["RefreshRules"], path: "Tests/RefreshRulesTests"),
    .target(name: "TransferRules", path: "LiveContainerSwiftUI/Models", sources: ["TransferItem.swift"]),
    .testTarget(name: "TransferRulesTests", dependencies: ["TransferRules"], path: "Tests/TransferRulesTests")
])
