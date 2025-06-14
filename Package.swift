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
        .package(
    url: "https://github.com/Cocoanetics/SwiftMCP.git",
    branch: "main"          // ← use branch until they publish a tag
),
        
        // Swift Subprocess for enhanced process management
        // BEFORE
.package(
    url: "https://github.com/swiftlang/swift-subprocess.git",
    branch: "main"
),


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
                .enableUpcomingFeature("StrictConcurrency"),
                .define("DEVELOPMENT", .when(configuration: .debug)),
                .define("RELEASE", .when(configuration: .release)),
                .unsafeFlags(["-O", "-whole-module-optimization"], .when(configuration: .release))
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
                .enableUpcomingFeature("StrictConcurrency"),
                .define("DEVELOPMENT", .when(configuration: .debug)),
                .define("RELEASE", .when(configuration: .release)),
                .unsafeFlags(["-O", "-whole-module-optimization"], .when(configuration: .release))
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
