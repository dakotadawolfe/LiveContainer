// swift-tools-version: 5.9
import PackageDescription

let package = Package(name: "UnifiedManagerRules", products: [], targets: [
    .target(name: "RefreshRules", path: "SideStoreSupport", sources: ["RefreshRules.swift"]),
    .testTarget(name: "RefreshRulesTests", dependencies: ["RefreshRules"], path: "Tests/RefreshRulesTests")
])
