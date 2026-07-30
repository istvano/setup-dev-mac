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

## Shell portability

Scripts run on macOS, where `/bin/bash` is 3.2.57 and the userland is BSD. Use a
`while IFS= read -r` loop rather than `mapfile`, and no associative arrays;
`tests/shell-syntax.sh` rejects bash 4 builtins. Prefer POSIX flags, or probe for
the BSD form first as `tests/browser-profiles.sh` does with `stat`. See ADR-033.
