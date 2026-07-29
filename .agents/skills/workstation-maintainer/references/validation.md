# Validation matrix

## All changes

```bash
./script/test
```

## Package profiles

```bash
./script/render-brewfile --output /tmp/workstation.Brewfile
./tests/render-brewfile.sh
```

## Package profiles (token freshness)

```bash
./script/check-tokens
```

Needs network access, so it is not part of `./script/test`.

## Shell scripts

```bash
bash -n path/to/script
shellcheck -x path/to/script
shfmt -d -i 2 -ci path/to/script
```

`script/shell-files` is the single source of truth for which files are shell
scripts. Never add a separate selector.

## Chezmoi templates

```bash
./tests/chezmoi-templates.sh
```

Repository paths must use `dir .chezmoi.sourceDir`; `.chezmoiroot` makes
`.chezmoi.sourceDir` the `chezmoi/` subdirectory.

## macOS defaults and hardening

```bash
./script/macos-defaults --dry-run
./script/macos-defaults --diff
./script/macos-defaults --verify
./script/hardening-check --strict
```

## Project-local MLX

```bash
uv add mlx
# On the target Mac, run the project's MLX-specific verification.
```

## Chezmoi

```bash
chezmoi diff
```
