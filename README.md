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
  --shell zsh \
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

The default free choices are zsh, Rancher Desktop with Moby, Bitwarden and LuLu.
OrbStack, 1Password and Little Snitch are paid alternatives. Colima is the
CLI-only container-runtime alternative, and fish is the alternative interactive
shell (see [Interactive shell](#interactive-shell)).

Follow [Operations](docs/OPERATIONS.md) for the complete first-install,
verification, update, hardening and package-reconciliation procedures.

## Package profiles

Host packages are defined by composable Brewfile fragments:

- `core`: bootstrap trust set, terminal, editor, Git and frequently used CLI
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
- `fonts`: Nerd Fonts, including the symbols-only font usable as a fallback
- `mcp`: the official MCP inspector, for reviewing a server before trusting it
- `local-llm`: LM Studio, the one permitted local inference runtime (ADR-025)
- `productivity-extra`: optional browsers, VPN, notes, media and desktop
  utilities
- `paid`: non-alternative paid additions

The default profiles are `core,dev,security,productivity,backup`, which install
48 packages with zsh, or 47 with fish. The default carries one tool per job (ADR-022) and no language
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

## Fonts

`core` installs JetBrainsMono Nerd Font, which `dot_config/ghostty/config`
selects, so the terminal glyphs used by starship and `eza --icons` always work.

The opt-in `fonts` profile adds a curated set from
[ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts). The one worth
singling out is `font-symbols-only-nerd-font`: it is glyphs with no alphabet, so
naming it as a second `font-family` in Ghostty upgrades any unpatched font
without replacing it.

These arrive as Homebrew casks, which download the release archives from that
project and verify a pinned SHA-256. The upstream `install.sh` is not used: it
clones a multi-gigabyte repository and runs a remote script outside the trust
boundary in [Security](SECURITY.md).

## VS Code extensions

`vscode/extensions.list` declares extensions with exact pinned versions, applied
by `script/vscode-extensions` and by a chezmoi hook when `dev` is selected.
Extension packs are declared by their root only. See
[vscode/README.md](vscode/README.md) and ADR-032.

```bash
just extensions-verify   # non-zero when the installed set has drifted
just extensions-diff     # includes what arrives as a pack child
```

## Platform

Apple Silicon is the target. Intel macOS is supported as a development platform
so the configuration can be built and tested before the arm64 machine exists
(ADR-034); the Homebrew prefix is discovered rather than assumed, and
`require_supported_mac` warns rather than passing silently, because the two are
not equivalent.

What the current machine cannot install is reported rather than remembered:

```bash
just gaps          # or ./script/platform-gaps
```

`./bootstrap plan` runs it too, so the gap is visible before an install rather
than as a `brew bundle` failure partway through one.

## Interactive shell

zsh is the default. `--shell fish` installs fish instead, and the two are
mutually exclusive: selecting fish drops `zsh-autosuggestions` and
`zsh-syntax-highlighting`, because fish provides both natively.

Selecting fish does **not** change the account login shell. Ghostty is
configured to run fish directly, so a fish configuration that fails to parse
costs a terminal tab rather than the ability to log in, and zsh stays available
for SSH, recovery and anything reading `$SHELL`. `chsh` remains a documented
manual step in [Operations](docs/OPERATIONS.md#interactive-shell); chezmoi
reports the difference on every apply and changes nothing.

Both configurations activate the same tools — mise, direnv, starship, zoxide,
fzf and Atuin — and neither installs a plugin manager. `~/.config/fish` is only
written when fish is selected.

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
├── tests/             # Static, template and idempotency checks
└── vscode/            # Declared VS Code extensions, pinned
```

## Development

Run the validation suite for every change:

```bash
./script/test
```

It covers shell syntax and shellcheck, shfmt, actionlint, gitleaks, Brewfile
rendering, profile-catalogue consistency, chezmoi template execution, YAML,
placement invariants, render idempotency, browser profiles and agent context.

Nothing here has been validated on macOS by CI, which runs Linux with bash 5
while macOS ships bash 3.2 (ADR-033). To test on a real Mac, push the working
tree to it and run there:

```bash
export MAC_TEST_HOST=user@host MAC_TEST_PORT=22
./script/sync-to-mac ./script/test
```

`sync-to-mac` uses rsync rather than a clone, because a test machine may not
reach the git remote and a clean macOS has no `git` until Xcode Command Line
Tools are installed. It verifies that `.git` and the executable bits survived the
transfer — both failures otherwise surface much later as unrelated errors — and
forwards the remote exit status.

Homebrew renames tokens continuously, so the declared package set is checked
against upstream separately. This is the only check that needs network access,
and it also runs weekly in CI:

```bash
./script/check-tokens
./script/check-extensions
```

Repository-wide and directory-specific agent instructions are in `AGENTS.md`
files. Repo-local workflows live under `.agents/skills/`. Start Codex from the
repository root:

```bash
codex
```

## Manual security work

Some of the workstation cannot be automated: FileVault's recovery key has to
leave the machine, TCC consent dialogs exist precisely so no script may click
them, and disabling a remote service you are connected over would strand you.

[docs/MANUAL-SECURITY.md](docs/MANUAL-SECURITY.md) is the checklist — ten items,
each with what to do, why it is not automated, and how to verify it. The last
apply hook points at it, and `./script/hardening-check` reports which are done.

## Trust model

Read every selected profile and every apply script before use. The Homebrew
bootstrap installer, packages, casks, project container images, editor
extensions, MCP servers and coding agents all expand the trusted computing
base.
