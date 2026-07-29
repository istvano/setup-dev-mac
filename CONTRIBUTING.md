# Contributing

Before changing this security-sensitive workstation baseline:

1. Read `AGENTS.md`, the nearest nested `AGENTS.md`, and the applicable
   architecture, decision and operations documents.
2. Keep the macOS host minimal and preserve the documented host, project,
   container and VM boundaries.
3. Give every package a concrete use case, placement reason, profile, conflict
   analysis and licence classification.
4. Keep scripts small and idempotent; keep `justfile` recipes as command aliases.
5. Update behaviour, documentation and tests in the same patch.
6. Run:

   ```bash
   ./script/test
   ```

7. On macOS, also render the selected Brewfile, verify current package tokens
   and inspect `chezmoi diff`.

Broad repository work uses the repo-local `$workstation-maintainer` skill.
Package decisions use `$add-workstation-tool`.
