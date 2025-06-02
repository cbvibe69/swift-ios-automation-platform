### Task 9: Implement File System Monitoring
**Priority:** MEDIUM - Real-time change detection

**Description:** Create file system monitoring capabilities to detect project changes in real-time for proactive build intelligence.

**Files to Create:**
- `Sources/AutomationCore/FileSystem/FileSystemMonitor.swift`
- `Sources/AutomationCore/FileSystem/ProjectWatcher.swift`

**Specific Actions:**
1. Implement `FileSystemMonitor` using `DispatchSource`:
   - Monitor Swift source files for changes
   - Watch project configuration files
   - Track build artifacts and derived data
2. Create `ProjectWatcher` actor for project-specific monitoring:
   - Smart filtering of relevant changes
   - Debouncing rapid changes
   - Change categorization (source, config, resources)
3. Integrate with `BuildIntelligenceEngine` for proactive analysis
4. Add configurable monitoring rules

**Acceptance Criteria:**
- Real-time file change detection with <100ms latency
- Smart filtering to ignore irrelevant changes
- Integration with build intelligence for proactive analysis
