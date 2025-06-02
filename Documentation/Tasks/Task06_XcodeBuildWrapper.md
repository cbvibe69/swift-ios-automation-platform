### Task 6: Implement XcodeBuild Wrapper with Enhanced Output Parsing
**Priority:** HIGH - Core build functionality

**Description:** Create a comprehensive wrapper around `xcodebuild` that provides structured output parsing and real-time feedback.

**Files to Create:**
- `Sources/AutomationCore/Build/XcodeBuildWrapper.swift`
- `Sources/AutomationCore/Build/BuildOutputParser.swift`

**Files to Modify:**
- `Sources/AutomationCore/SimpleMCPHandler.swift`

**Specific Actions:**
1. Create `XcodeBuildWrapper` class that:
   - Handles all `xcodebuild` operations (build, test, archive, analyze)
   - Provides real-time output streaming
   - Implements proper process management with cancellation
2. Implement `BuildOutputParser` that extracts:
   - Compilation errors and warnings
   - Build timing information
   - Success/failure status
   - Performance metrics
3. Replace basic `Process` usage in `SimpleMCPHandler`
4. Add support for multiple schemes and destinations

**Acceptance Criteria:**
- Real-time build output streaming
- Structured error/warning extraction
- Support for all major `xcodebuild` operations
- Proper process cleanup and cancellation
