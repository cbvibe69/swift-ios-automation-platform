# API Reference

*Auto-generated on 6/2/2025, 2:15 AM*

## Unknown

### AutomationCoreTests.swift

**Dependencies:**
- `XCTest`

### XcodeAutomationServerTests.swift

**Dependencies:**
- `XCTest`
- `Logging`

### Package.swift

**Dependencies:**
- `PackageDescription`

### main.swift

**Dependencies:**
- `Foundation`
- `Logging`
- `AutomationCore`

### ResourceManager.swift

**Classes/Structs/Actors:**
- `ResourceManager`

**Public Functions:**
- `executeWithResourceControl<T:`
- `calculateOptimalSimulatorCount`
- `optimizeResourceAllocation`

**Dependencies:**
- `Foundation`
- `Logging`

### DocGenerator.swift

**Classes/Structs/Actors:**
- `DocGenerator`
- `DocumentationResult`
- `SwiftFileInfo`
- `DocComment`
- `APIDocumentation`
- `ArchitectureDocumentation`
- `ComponentDocumentation`
- `MCPToolDocumentation`
- `MCPToolExample`
- `ProjectStructure`
- `ProjectModule`

**Public Functions:**
- `generateProjectDocumentation`
- `generateLiveMCPToolDocumentation`

**Dependencies:**
- `Foundation`
- `Logging`
- `SystemPackage`

### SandboxManager.swift

**Public Functions:**
- `prepareSandbox`

**Dependencies:**
- `Foundation`
- `Logging`

### PathValidator.swift

**Classes/Structs/Actors:**
- `PathValidator`

**Public Functions:**
- `resolvedPath`
- `isTraversalSafe`
- `isWhitelisted`

**Dependencies:**
- `Foundation`

### FileSystemMonitor.swift

**Classes/Structs/Actors:**
- `FileSystemMonitor`
- `FileChangeEvent`
- `FileMetadata`
- `ProjectChangeEvent`
- `BuildLogEvent`

**Public Functions:**
- `startMonitoring`
- `stopMonitoring`
- `stopAllMonitoring`
- `getMonitoredPaths`
- `startProjectMonitoring`
- `startBuildLogMonitoring`

**Dependencies:**
- `Foundation`
- `Logging`
- `Dispatch`

### EnhancedToolHandlers.swift

**Classes/Structs/Actors:**
- `EnhancedToolHandlers`

**Public Functions:**
- `handleEnhancedBuild`
- `handleEnhancedSimulator`
- `handleEnhancedFileOperations`
- `handleEnhancedProjectAnalysis`
- `handleVisualDocumentation`

**Dependencies:**
- `Foundation`
- `Logging`

### MCPProtocol.swift

**Classes/Structs/Actors:**
- `MCPRequest`
- `MCPResponse`
- `MCPError`
- `AnyCodable`
- `MCPServerCapabilities`
- `MCPToolsCapability`
- `MCPPromptsCapability`
- `MCPResourcesCapability`
- `MCPLoggingCapability`
- `MCPTool`
- `MCPToolInputSchema`
- `MCPPropertySchema`
- `MCPToolResult`
- `MCPImageContent`
- `MCPResourceContent`
- `MCPInitializeParams`
- `MCPClientCapabilities`
- `MCPRootsCapability`
- `MCPClientInfo`
- `MCPInitializeResult`
- `MCPServerInfo`
- `MCPProtocolHandler`

**Public Functions:**
- `encode`
- `encode`
- `encode`
- `processRequest`

**Dependencies:**
- `Foundation`
- `Logging`

### MCPToolRegistry.swift

**Classes/Structs/Actors:**
- `MCPToolRegistry`
- `RegisteredTool`
- `MCPToolBuilder`

**Public Functions:**
- `registerTool`
- `getAllTools`
- `getRegisteredTools`
- `executeTool`

**Dependencies:**
- `Foundation`
- `Logging`

### UITestScenario.swift

**Classes/Structs/Actors:**
- `UITestScenario`
- `UITestStep`

**Dependencies:**
- `Foundation`

### ProjectTemplate.swift

### XcodeProject.swift

**Classes/Structs/Actors:**
- `XcodeProject`
- `XcodeProjectFile`

**Dependencies:**
- `Foundation`

### AdditionalPlaceholders.swift

**Classes/Structs/Actors:**
- `ProjectOptions`
- `ProjectCreationResult`
- `SimulatorLaunchResult`
- `UITestResult`
- `ErrorAnalysis`
- `PerformanceMetrics`
- `RawBuildResult`
- `FileOperationResult`
- `HardwareSpec`
- `ResourceUsage`
- `HardwareDetection`
- `ResourceMonitor`
- `SecurityManager`
- `SimulatorDevice`

**Public Functions:**
- `getCurrentUsage`
- `snapshot`
- `validateProjectPath`

**Dependencies:**
- `Foundation`

### Hardware.swift

**Public Functions:**
- `detectHardwareCapabilities`
- `calculateOptimalSimulatorCount`
- `detectAppleSilicon`
- `detectM2MaxSpecifically`

**Dependencies:**
- `Foundation`

### XcodeAutomationMCPServer.swift

**Classes/Structs/Actors:**
- `ServerConfiguration`

**Public Functions:**
- `startStdioTransport`
- `startTCPTransport`
- `stop`

**Dependencies:**
- `Foundation`
- `SwiftMCP`
- `Logging`
- `Subprocess`
- `ConcurrencyExtras`
- `SystemPackage`

### XcodeBuildWrapper.swift

**Classes/Structs/Actors:**
- `XcodeBuildWrapper`
- `BuildOptions`
- `TestOptions`
- `BuildResult`
- `TestResult`
- `BuildError`
- `BuildWarning`
- `TestCase`
- `XcodeScheme`
- `ProcessResult`

**Public Functions:**
- `buildProject`
- `runTests`
- `listSchemes`
- `getBuildSettings`

**Dependencies:**
- `Foundation`
- `Logging`
- `Darwin`

