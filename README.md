# mac-security-ai-workstation

A secure, reproducible Apple Silicon workstation baseline for software
engineering, security engineering and project-local MLX workloads.

The target is an Apple Silicon MacBook Pro with 128 GB unified memory, 4 TB
storage and macOS on `arm64`.

## Design

Work is placed in the smallest boundary that provides the capabilities it
needs:

| Domain | Responsibility |
|---|---|
| macOS host | GUI applications, identity integration, display/network/system tools and frequently used CLI tools |
| Project-local uv environment | MLX workloads that need Apple unified memory and Metal |
| Project containers | Project-owned services, scanners and CI-equivalent dependencies |
| Isolated Linux VM | Exploit development, GDB workflows, untrusted binaries, malware analysis and x86-specific work |

See [Architecture](docs/ARCHITECTURE.md) for the current design and
[Architectural decisions](docs/DECISIONS.md) for the reasons behind it.

## Quick start

Review the planned choices before installation:

```bash
./bootstrap plan
```

Run the interactive bootstrap:

```bash
./bootstrap install
```

Or provide the choices explicitly:

```bash
./bootstrap install \
  --profiles core,dev,security,productivity \
  --runtime rancher \
  --password-manager bitwarden \
  --firewall lulu \
  --git-name "Your Name" \
  --git-email "you@example.com" \
  --with-hardening
```

The default free choices are Rancher Desktop with Moby, Bitwarden and LuLu.
OrbStack, 1Password and Little Snitch are paid alternatives. Colima is the
CLI-only container-runtime alternative.

Follow [Operations](docs/OPERATIONS.md) for the complete first-install,
verification, update, hardening and package-reconciliation procedures.

## Package profiles

Host packages are defined by composable Brewfile fragments:

- `core`: bootstrap trust set, shell, Git and frequently used CLI
- `dev`: editors, language managers and local repository validation
- `security`: frequently used host-network and cryptographic inspection tools
- `productivity`: BetterDisplay, the required native display dependency
- `cloud`: OpenTofu only
- `cloud-aws`, `cloud-azure`, `cloud-gcp`: provider-specific control-plane CLIs
- `kubernetes`: Kubernetes control-plane and interactive operations
- `data`: embedded SQL CLIs and native database/API clients
- `security-extra`: Burp and optional privileged/native security inspection
- `productivity-extra`: optional browsers, identity, notes and desktop utilities
- `paid`: non-alternative paid additions

The default profiles are `core,dev,security,productivity`. Specialist profiles
are opt-in. Container runtimes, password managers and outbound firewalls use
separate mutually exclusive fragments.

## Project-local MLX

MLX is not a workstation profile or global environment. Each Apple Silicon
project declares the Python packages and version it needs:

```bash
uv add mlx
```

Add `mlx-lm`, notebooks, model tooling and serving dependencies only to the
projects that use them. Development servers must bind to loopback and must not
be presented as production-safe.

## Project containers

This repository provides a selected Docker-compatible runtime but no shared
Compose stack. Each project owns its services, scanners, versions, volumes,
ports, credentials and teardown policy.

For Rancher Desktop, chezmoi selects Moby and disables Kubernetes by default so
Compose and Testcontainers have the Docker API without an unused Kubernetes
control plane.

## Shell history

Atuin stores history locally by default. Automatic sync, update checks, its
background daemon and Atuin AI are disabled. Selected entries are inserted for
review rather than executed immediately.

Import existing zsh history explicitly when ready:

```bash
atuin import auto
```

Continue to pass secrets through prompts, environment files or secret managers
rather than command-line arguments.

## Browser isolation

Selecting `productivity-extra` provisions separate `personal` and `work` data
roots for Chrome and Firefox Developer Edition. Launch them with:

```bash
browser-profile open chrome personal
browser-profile open firefox work
```

Use `browser-profile add NAME` to create additional isolated contexts. See
[Operations](docs/OPERATIONS.md#browser-profiles) for limitations and the full
workflow.

## Repository layout

```text
.
├── AGENTS.md          # Repository-wide Codex instructions
├── TASKS.md           # Unfinished work only
├── bootstrap          # Minimal trust bootstrap
├── chezmoi/           # Dotfiles, configuration and apply hooks
├── docs/              # Architecture, decisions and operations
├── profiles/          # Composable host Brewfile fragments
├── script/            # Canonical orchestration and validation
└── tests/             # Static and idempotency checks
```

## Development

Run the validation suite for every change:

```bash
./script/test
```

Repository-wide and directory-specific agent instructions are in `AGENTS.md`
files. Repo-local workflows live under `.agents/skills/`. Start Codex from the
repository root:

```bash
codex
```

## Trust model

Read every selected profile and every apply script before use. The Homebrew
bootstrap installer, packages, casks, project container images, editor
extensions, MCP servers and coding agents all expand the trusted computing
base.
