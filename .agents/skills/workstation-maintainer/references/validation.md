# Validation matrix

## All changes

```bash
REQUIRE_LINTERS=1 REQUIRE_CHEZMOI=1 ./script/test
```

Without the `REQUIRE_*` variables, four checks skip silently when their tool is
absent — shellcheck, shfmt/actionlint/gitleaks, chezmoi template execution and
YAML — and the suite still prints "All repository tests passed".

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

## Installation changes

```bash
./script/test-install
```

Destructive, in the disposable macOS guest (ADR-036). Requires a sealed golden
image: `./script/install-tart && ./script/vm build && ./script/vm seal`.

It cannot prove three things, which must not be reported as passing: no container
runtime runs inside the guest (nested virtualization needs M3 or later), Apple's
licence permits two macOS guests per host so matrices are sequential, and Ghostty
needs Metal.

## The tart pin

```bash
./script/install-tart --verify
./tests/vm.sh
```
