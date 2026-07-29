---
name: workstation-maintainer
description: Maintain or review this mac-security-ai-workstation repository. Use for bootstrap, chezmoi, Brewfile profile, container, MLX, validation, documentation, security-boundary, refactoring, first-install readiness, or cross-cutting repository changes.
---

# Workstation maintainer

## Workflow

1. Read repository `AGENTS.md`, `docs/ARCHITECTURE.md`,
   `docs/DECISIONS.md` and `TASKS.md`.
2. Read the nearest nested `AGENTS.md` for each directory to be changed.
3. Run `git status` and preserve unrelated work.
4. Run `./script/test` before editing to establish the baseline when feasible.
5. Identify the source of truth and avoid duplicate implementations.
6. Make the smallest coherent patch preserving host/container/VM boundaries.
7. Update tests and documentation in the same patch.
8. Run `./script/test` after editing and area-specific checks from
   `references/validation.md`.
9. Report changed files, architecture impact, tests, unresolved risks and any
   validation that requires the actual Mac.

## Guardrails

- Do not change accepted decisions silently.
- Do not add Ollama, llama.cpp, PyTorch or Open WebUI without explicit user
  direction and a decision-record update.
- Do not install service daemons on the host when the container boundary is
  equivalent.
- Do not expose container or MLX endpoints beyond loopback by default.
- Do not commit or push unless explicitly asked.
