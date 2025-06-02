# Contributor Workflow

## Environment Requirements
- Use **Swift 6** and **Xcode 16.5+** for all development.
- A startup script exists at `.codex/setup.sh` to prepare dependencies.

## Build and Test
- After any changes, run:
  ```bash
  swift build
  swift test
  ```
  Validate the build and tests succeed (or note failures in your PR).

## Helper Scripts
- Additional automation scripts are located in the `Scripts/` directory.
- They can streamline building, testing, and running the project.

