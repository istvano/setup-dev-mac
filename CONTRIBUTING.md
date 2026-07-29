# Contributing

## Principles

- Keep the macOS host minimal.
- Preserve MLX as the initial local-AI baseline.
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
ruby -c /tmp/Brewfile
chezmoi diff
```
