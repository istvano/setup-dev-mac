# mac-security-ai-workstation

A secure and reproducible Apple Silicon workstation baseline for software
engineering, security engineering and project-local MLX workloads.

Target machine:

- MacBook Pro with Apple Silicon
- 128 GB unified memory
- 4 TB SSD
- macOS on `arm64`

## Design

The repository deliberately separates four execution domains:

| Domain | Responsibility |
|---|---|
| macOS host | GUI applications, Keychain/Touch ID integration, display/network/system tools and low-latency CLI use |
| Project-local uv environment | MLX workloads that need Apple unified memory and Metal-backed execution |
| Project containers | Project-owned services, scanners and CI-equivalent dependencies |
| Isolated Linux VM | Exploit development, GDB workflows, untrusted binaries, malware analysis and x86-specific work |

MLX is installed as a Python dependency of each project that needs it. MLX-LM
and other model tooling are also project decisions rather than global
workstation dependencies.

BetterDisplay Free Edition is installed natively because display discovery,
HiDPI scaling, DDC/brightness control and macOS display APIs cannot be delegated
to a Linux container.

## Repository layout

```text
.
├── AGENTS.md                     # Repository-wide Codex instructions
├── TASKS.md                      # Current operational backlog
├── .agents/skills/               # Repo-local Codex workflows
├── bootstrap                     # Strap-inspired trust bootstrap
├── .chezmoiroot                  # Makes chezmoi/ the source-state root
├── chezmoi/                      # Dotfiles, generated user config and apply scripts
├── profiles/                     # Composable host Brewfile fragments
├── script/                       # Small idempotent operations
├── tests/                        # Static and idempotency checks
├── docs/                         # Architecture and durable decisions
└── .github/workflows/            # CI validation
```

## Secure bootstrap

The bootstrap borrows selected ideas from Strap:

- validates macOS and Apple Silicon
- installs Xcode Command Line Tools
- installs Homebrew from the official installer
- installs only the bootstrap trust set: Git, GitHub CLI, `age` and chezmoi
- enables immediate screen-lock password enforcement
- optionally enables the macOS firewall and stealth mode
- checks FileVault state but does not export a recovery key to the Desktop
- does not enable network services
- is idempotent

It intentionally does **not** silently:

- install Rosetta
- enable FileVault
- modify Touch ID PAM policy
- install macOS major upgrades
- run Git submodules
- overwrite unreviewed dotfiles without a chezmoi diff/apply boundary

## First installation

Review the repository first:

```bash
./bootstrap plan
```

Run the interactive bootstrap:

```bash
./bootstrap install
```

Example with explicit choices:

```bash
./bootstrap install \
  --profiles core,dev,ai,security,cloud,data,productivity \
  --runtime rancher \
  --password-manager bitwarden \
  --firewall lulu \
  --git-name "Your Name" \
  --git-email "you@example.com" \
  --with-hardening
```

Paid alternatives:

```bash
./bootstrap install \
  --runtime orbstack \
  --password-manager 1password \
  --firewall little-snitch \
  --profiles core,dev,ai,security,cloud,data,productivity,paid
```

## Applying changes later

```bash
./script/setup
```

Preview first:

```bash
chezmoi diff
```

Update from Git and apply:

```bash
./script/update
```

## Package profiles

Profiles are explicit Brewfile fragments:

- `core`: shell, Git, dotfiles and core CLI
- `dev`: editors and language tooling
- `ai`: no global package; documents project-local MLX placement
- `security`: native interactive and host-integrated security tooling
- `cloud`: cloud/Kubernetes/IaC control-plane CLIs
- `data`: embedded SQL CLIs and native database/API clients
- `productivity`: browsers, identity, notes, BetterDisplay and desktop utilities
- `paid`: CleanShot and other non-alternative paid additions

Runtime, password-manager and outbound-firewall alternatives are separate
fragments so mutually exclusive products are not installed together.

## Shell history

The core profile installs Atuin and initialises it for zsh. History stays in
Atuin's local SQLite database by default: automatic sync, update checks, the
background daemon and Atuin AI are disabled. Selected history entries are
inserted for review rather than executed immediately.

Import existing zsh history explicitly when ready:

```bash
atuin import auto
```

## Project-local MLX

MLX is distributed as a Python package rather than a standalone host
application. Add it to each Apple-Silicon project's uv environment:

```bash
uv add mlx
```

Add `mlx-lm`, Hugging Face tooling, notebooks and model-serving dependencies
only when that project's workload requires them. This keeps versions and model
tooling isolated while still using Metal and unified memory natively.

## Project containers

The workstation provides a Docker-compatible runtime but no global Compose
stack. Each project owns its services, scanners, image versions, volumes and
teardown policy. For Rancher Desktop, chezmoi selects the Moby engine and
disables Kubernetes by default because Compose and Testcontainers require the
Docker API.

## Verification

```bash
./script/verify
./script/hardening-check
```

## Development and CI

```bash
./script/test
```

The tests validate shell syntax, Brewfile rendering, YAML syntax, forbidden host
packages, placement invariants and render idempotency.

## Continue with Codex CLI

The development profile installs Codex CLI. Repository-wide and directory-specific
instructions are defined in `AGENTS.md` files, and reusable workflows live under
`.agents/skills/`.

Start Codex directly from the repository root:

```bash
codex
```

## Publishing to GitHub

Create an empty repository, then:

```bash
git init
git add .
git commit -m "Initial workstation baseline"
git branch -M main
git remote add origin git@github.com:YOUR_USER/mac-security-ai-workstation.git
git push -u origin main
```

On another Mac:

```bash
git clone git@github.com:YOUR_USER/mac-security-ai-workstation.git \
  ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
./bootstrap install
```

## Trust model

Read every profile and every script before use. Homebrew casks, project
container images, VS Code extensions, MCP servers and coding agents all extend
the trusted computing base.
