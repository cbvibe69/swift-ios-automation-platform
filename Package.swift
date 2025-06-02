// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftXcodeAutomationPlatform",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "XcodeAutomationServer",
            targets: ["XcodeAutomationServer"]
        ),
        .library(
            name: "AutomationCore",
            targets: ["AutomationCore"]
        )
    ],
    dependencies: [
        // Official MCP Swift SDK (when available)
        // .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "1.0.0"),
        
        // SwiftMCP Framework (Cocoanetics)
        .package(url: "https://github.com/cocoanetics/SwiftMCP.git", from: "1.0.0"),
        
        // Swift Subprocess for enhanced process management
        .package(url: "https://github.com/apple/swift-subprocess.git", from: "0.0.1"),
        
        // ArgumentParser for CLI
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        
        // Swift Log for comprehensive logging
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        
        // Swift Concurrency Extras for advanced async patterns
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras.git", from: "1.1.0"),
        
        // Swift Collections for performance data structures
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        
        // Swift System for low-level system integration
        .package(url: "https://github.com/apple/swift-system.git", from: "1.2.0")
    ],
    targets: [
        // Main executable target
        .executableTarget(
            name: "XcodeAutomationServer",
            dependencies: [
                "AutomationCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SwiftMCP", package: "SwiftMCP")
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("ImplicitOpenExistentials"),
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        
        // Core automation library
        .target(
            name: "AutomationCore",
            dependencies: [
                .product(name: "Subprocess", package: "swift-subprocess"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "SwiftMCP", package: "SwiftMCP")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        
        // Test targets
        .testTarget(
            name: "XcodeAutomationServerTests",
            dependencies: ["XcodeAutomationServer"]
        ),
        .testTarget(
            name: "AutomationCoreTests",
            dependencies: ["AutomationCore"]
        )
    ]
)

// Enable build optimizations for release builds
#if swift(>=5.9)
package.targets.forEach { target in
    if target.type == .executable {
        target.swiftSettings = (target.swiftSettings ?? []) + [
            .unsafeFlags([
                "-O",
                "-whole-module-optimization"
            ], .when(configuration: .release))
        ]
    }
}
#endif