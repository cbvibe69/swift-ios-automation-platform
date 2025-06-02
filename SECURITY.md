# Security Policy

This project is designed with a strict sandbox model and local-only communication.

## Sandbox Approach

- The server runs under the macOS App Sandbox.
- Access to user directories and network resources is denied unless explicitly granted by the user.
- All file operations are validated and scoped to allowed locations.

## Local‑Only Transport

- Automation commands are executed using local inter‑process communication.
- No external network transport is enabled by default.
- Remote access must be explicitly added and is disabled in the reference implementation.

## Reporting a Vulnerability

Please report suspected vulnerabilities by opening a private security advisory or emailing the maintainers.
Include reproducible steps and any relevant logs.

We aim to respond to security reports within a few business days.
