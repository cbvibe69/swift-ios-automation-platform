### Task 12: Extract r-huijts Project Management Patterns
**Priority:** MEDIUM - Project manipulation

**Description:** Extract and enhance the project management patterns from `r-huijts/xcode-mcp-server` for creating and modifying Xcode projects.

**Files to Create:**
- `Sources/AutomationCore/Project/XcodeProjectManager.swift`
- `Sources/AutomationCore/Project/PbxprojParser.swift`

**Specific Actions:**
1. Study r-huijts project management implementation
2. Implement `PbxprojParser` for:
   - Reading and parsing .pbxproj files
   - Safe modification of project structure
   - Adding files and targets to projects
3. Create `XcodeProjectManager` for high-level operations:
   - Project creation from templates
   - File addition and organization
   - Target configuration management
4. Add MCP tools for project manipulation

**Acceptance Criteria:**
- Safe .pbxproj file manipulation
- Project creation from standard templates
- File and target management capabilities
