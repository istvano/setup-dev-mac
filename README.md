# mac-security-ai-workstation

A secure, reproducible Apple Silicon workstation baseline for software
engineering, security engineering and project-local MLX workloads.

The project name is independent of the directory it is checked out into; every
command resolves its own repository root.

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
  --profiles core,dev,security,productivity,backup \
  --runtime rancher \
  --password-manager bitwarden \
  --firewall lulu \
  --git-name "Your Name" \
  --git-email "you@example.com" \
  --with-hardening
```

Optional identity and privilege choices, all disabled by default:

```bash
  --git-signing-method gpg                  # gpg (default), ssh or none
  --git-signing-key "0xABCD1234..."         # GPG key ID, or an SSH public key
  --work-git-dir "~/work"                   # directory using a work identity
  --work-git-email "you@employer.example"   # identity used inside it
  --with-touchid-sudo                       # Touch ID for sudo via sudo_local
```

The default free choices are Rancher Desktop with Moby, Bitwarden and LuLu.
OrbStack, 1Password and Little Snitch are paid alternatives. Colima is the
CLI-only container-runtime alternative.

Follow [Operations](docs/OPERATIONS.md) for the complete first-install,
verification, update, hardening and package-reconciliation procedures.

## Package profiles

Host packages are defined by composable Brewfile fragments:

- `core`: bootstrap trust set, shell, editor, Git and frequently used CLI
- `dev`: editors, language managers and local repository validation
- `security`: the general TLS and cryptographic toolkit
- `productivity`: BetterDisplay, required for DDC monitor input switching
- `cloud`: OpenTofu and module documentation
- `cloud-aws`, `cloud-azure`, `cloud-gcp`: provider-specific control-plane CLIs
- `kubernetes`: Kubernetes control-plane and interactive operations
- `data`: embedded SQL CLIs and native database/API clients
- `security-extra`: host-network and PKI tooling, hardware security keys,
  privileged and macOS monitoring tools
- `security-scan`: single-binary scanners for interactive use (see ADR-015)
- `backup`: restic and rclone for encrypted, verifiable off-site backup
- `lab`: Lima, UTM and Ansible — the isolated Linux VM domain and local lab
- `docs`: d2, pandoc and draw.io for diagrams and stakeholder documents
- `mcp`: the official MCP inspector, for reviewing a server before trusting it
- `local-llm`: LM Studio, the one permitted local inference runtime (ADR-025)
- `productivity-extra`: optional browsers, VPN, notes, media and desktop
  utilities
- `paid`: non-alternative paid additions

The default profiles are `core,dev,security,productivity,backup`, which install
48 packages. The default carries one tool per job (ADR-022) and no language
runtime: Node, Go, Java, Rust and pnpm come from mise (ADR-021), and any other
language is one `mise use -g <lang>` away. Specialist profiles are opt-in. Container runtimes, password managers and outbound firewalls use
separate mutually exclusive fragments.

## Local AI

MLX is not a workstation profile or global environment. Each Apple Silicon
project declares the Python packages and version it needs:

```bash
uv add mlx mlx-lm
```

Add notebooks, model tooling and serving dependencies only to the projects that
use them. Development servers must bind to loopback and must not be presented as
production-safe. There is no `huggingface-cli` formula; install the CLI as an
isolated uv tool with `uv tool install "huggingface_hub[cli]"`.

LM Studio is the one permitted local inference runtime, in the opt-in
`local-llm` profile. It self-updates outside `brew upgrade`, its server must stay
on loopback, and the model weights are the trust surface rather than the app.
See [Operations](docs/OPERATIONS.md#local-ai-models) and
[ADR-025](docs/DECISIONS.md).

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

## macOS defaults

`script/macos-defaults` declares every setting in one table and verifies it by
reading the value back, because macOS silently ignores keys it no longer
honours. Always preview first:

```bash
./script/macos-defaults --dry-run
./script/macos-defaults --diff
./script/macos-defaults apply
./script/macos-defaults --verify
```

Gatekeeper quarantine, automatic FileVault and Rosetta are deliberately out of
scope. See [ADR-016](docs/DECISIONS.md).

## Commit signing

Signing is configured but inactive until a key is supplied. OpenPGP is the
default; `gnupg` and `pinentry-mac` are in the `core` profile and `~/.gnupg` is
managed with restrictive permissions.

```bash
gpg --full-generate-key
gpg --list-secret-keys --keyid-format=long
./bootstrap install --git-signing-key 0xYOURKEYID
```

See [Operations](docs/OPERATIONS.md#commit-signing) for the full workflow and
[ADR-017](docs/DECISIONS.md) for why OpenPGP is the default.

## Backup

Selecting `backup` installs restic and rclone. Nothing is scheduled
automatically and no repository is created for you; follow
[Operations](docs/OPERATIONS.md#backup), including the restore drill.

## Repository layout

```text
.
├── AGENTS.md          # Repository-wide Codex instructions
├── TASKS.md           # Unfinished work only
├── bootstrap          # Minimal trust bootstrap
├── chezmoi/           # Dotfiles, configuration and apply hooks
├── docs/              # Architecture, decisions and operations
├── mcp/               # Declared MCP policy and the ToolHive pin
├── profiles/          # Composable host Brewfile fragments
├── script/            # Canonical orchestration and validation
└── tests/             # Static, template and idempotency checks
```

## Development

Run the validation suite for every change:

```bash
./script/test
```

It covers shell syntax and shellcheck, shfmt, actionlint, gitleaks, Brewfile
rendering, profile-catalogue consistency, chezmoi template execution, YAML,
placement invariants, render idempotency, browser profiles and agent context.

Homebrew renames tokens continuously, so the declared package set is checked
against upstream separately. This is the only check that needs network access,
and it also runs weekly in CI:

```bash
./script/check-tokens
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
