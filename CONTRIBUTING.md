# Contributing

## Principles

- Keep the macOS host minimal.
- Keep MLX and related Python packages in project-local uv environments.
- Do not add overlapping package managers or container runtimes.
- Prefer small idempotent scripts over a monolithic installer.
- Every package entry needs a comment explaining its purpose and placement.
- Every new container must bind to loopback by default unless documented.

## Validation

```bash
./script/test
```

On macOS also run:

```bash
./script/render-brewfile --output /tmp/Brewfile
./tests/render-brewfile.sh
chezmoi diff
```

## Agent instructions

Read the root `AGENTS.md` and any nested `AGENTS.md` that applies to files you
change. For broad changes, use the repo-local `$workstation-maintainer` skill.
For package/tool decisions, use `$add-workstation-tool`.
