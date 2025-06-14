# Agent Development Guidelines

This repository supports AI-powered development workflows. Please follow these guidelines for contributing.

## Development Environment Setup

The project is automatically configured for AI agents through the `.codex/setup.sh` script which:

- Checks Swift and Xcode versions
- Resolves package dependencies  
- Validates build environment
- Provides system information for context

## Agent Workflow

1. **Initial Setup**: The setup script runs automatically when agents access the repository
2. **Build Commands**: Use `./Scripts/build.sh` for optimized builds
3. **Testing**: Use `./Scripts/test.sh` for comprehensive testing
4. **Development**: Follow the Phase-based development timeline in the PRD

## Task Workflow

The outstanding work items for Phase 1 are split into separate markdown files
under `Documentation/Tasks`. Agents should pick up the lowest numbered
`TaskXX_*.md` file that has not yet been implemented. After completing the
implementation for that task:

1. Run `./Scripts/build.sh` and `./Scripts/test.sh` to validate the changes.
2. Commit the results with a concise message referencing the task.
3. Proceed to the next numbered task file and repeat the process.

This ensures tasks are handled sequentially with build and test verification
between each step.

## Project Structure

- `Sources/AutomationCore/` - Core automation framework
- `Sources/XcodeAutomationServer/` - Main executable  
- `Tests/` - Test suites
- `Scripts/` - Build and development helpers
- `Documentation/` - Comprehensive project docs

## Key Guidelines

- Follow the comprehensive PRD for architectural decisions
- Implement security-first patterns with App Sandbox compliance
- Optimize for Mac Studio M2 Max performance (85-90% utilization)
- Use Swift structured concurrency with actors
- Maintain compatibility with Swift 6.0+ and macOS 14+

## Development Phases

- **Phase 1** (Weeks 1-2): Foundation + Core Extraction ← **Current**
- **Phase 2** (Weeks 3-4): Enhanced Swift Implementation  
- **Phase 3** (Weeks 5-6): Advanced Features + Optimization
- **Phase 4** (Weeks 7-8): Security Hardening + Production

For detailed implementation guidance, see the comprehensive PRD and Documentation folder.
