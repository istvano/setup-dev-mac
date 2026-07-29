---
name: add-workstation-tool
description: Evaluate and add, replace, remove, or reclassify a workstation tool. Use whenever the user proposes software, a GitHub project, CLI, GUI, service, database, scanner, AI runtime, security utility, paid application, container image, or macOS integration for this repository.
---

# Add workstation tool

## Decision process

1. Establish the concrete use case and whether an existing tool already covers
   it.
2. Verify current vendor documentation, Apple Silicon support, licence and
   Homebrew/image identifiers when network access is available.
3. Choose exactly one boundary using `references/placement.md`:
   host, native MLX project, container or isolated VM.
4. Analyse conflicts with existing package managers, runtimes, password
   managers, firewalls, databases and overlapping developer tools.
5. Prefer not adding the tool when the benefit is speculative or redundant.
6. If accepted, update the correct profile or manifest with an explanatory
   comment, documentation, decisions when architectural, and tests.
7. Run the relevant validation plus `./script/test`.

## Output contract

State:

- decision: add, defer, reject, replace or optional
- placement and rationale
- licence category
- conflicts and security implications
- files changed
- validation performed
