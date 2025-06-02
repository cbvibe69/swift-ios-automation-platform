### Task 7: Implement Simulator Management System
**Priority:** HIGH - Multi-simulator support

**Description:** Create comprehensive simulator management capabilities using `simctl` with support for concurrent operations.

**Files to Create:**
- `Sources/AutomationCore/Simulator/SimulatorManager.swift`
- `Sources/AutomationCore/Simulator/SimCtlWrapper.swift`

**Specific Actions:**
1. Implement `SimCtlWrapper` for all `simctl` operations:
   - List available devices
   - Boot/shutdown simulators
   - Install/uninstall apps
   - Take screenshots
   - Manage device state
2. Create `SimulatorManager` actor for concurrent operations:
   - Resource-aware simulator launching
   - Automatic cleanup and management
   - Health monitoring and recovery
3. Integrate with `ResourceManager` for optimal device allocation
4. Add MCP tools for simulator operations

**Acceptance Criteria:**
- Can manage 6+ simulators concurrently
- Automatic resource allocation and cleanup
- Full `simctl` feature coverage through Swift API
