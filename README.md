# mac-security-ai-workstation

A secure, container-first and reproducible Apple Silicon workstation baseline
for software engineering, security engineering and MLX-based local AI.

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
| Native MLX environment | MLX and MLX-LM workloads that need Apple unified memory and Metal-backed execution |
| Linux containers | Databases, vector stores, observability and repeatable batch scanners |
| Isolated Linux VM | Exploit development, GDB workflows, untrusted binaries, malware analysis and x86-specific work |

The initial AI baseline contains **MLX and MLX-LM only**. It intentionally omits
Ollama, llama.cpp and PyTorch until a concrete workload justifies them.

BetterDisplay Free Edition is installed natively because display discovery,
HiDPI scaling, DDC/brightness control and macOS display APIs cannot be delegated
to a Linux container.

## Repository layout

```text
.
├── bootstrap                     # Strap-inspired trust bootstrap
├── .chezmoiroot                  # Makes chezmoi/ the source-state root
├── chezmoi/                      # Dotfiles, generated user config and apply scripts
├── profiles/                     # Composable host Brewfile fragments
├── native-ai/                    # Source copy of the native MLX environment
├── containers/                   # Source copy of Compose and scanner tooling
├── script/                       # Small idempotent operations
├── tests/                        # Static and idempotency checks
└── .github/workflows/            # CI validation
```

The top-level `native-ai/` and `containers/` directories are canonical. Thin
chezmoi templates copy their contents into `~/.config/security-ai-workstation/`,
so runtime files have one source of truth.

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
  --sync-native-ai \
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
- `ai`: no global package dump; MLX lives in a `uv` project
- `security`: native interactive and host-integrated security tooling
- `cloud`: cloud/Kubernetes/IaC control-plane CLIs
- `data`: embedded SQL CLIs and native database/API clients
- `productivity`: browsers, identity, notes, BetterDisplay and desktop utilities
- `paid`: CleanShot and other non-alternative paid additions

Runtime, password-manager and outbound-firewall alternatives are separate
fragments so mutually exclusive products are not installed together.

## Native MLX

After apply:

```bash
~/.config/security-ai-workstation/native-ai/bin/mlxctl sync
~/.config/security-ai-workstation/native-ai/bin/mlxctl verify
```

Run a model:

```bash
~/.config/security-ai-workstation/native-ai/bin/mlxctl generate \
  mlx-community/Mistral-7B-Instruct-v0.3-4bit \
  "Explain passkeys."
```

Start the loopback-only development API:

```bash
~/.config/security-ai-workstation/native-ai/bin/mlxctl serve \
  mlx-community/Mistral-7B-Instruct-v0.3-4bit 8080
```

`mlx_lm.server` is a local development server, not a production gateway.

## Containers

Launch the selected Docker-compatible runtime, then:

```bash
~/.config/security-ai-workstation/containers/bin/wsctl pin-images
~/.config/security-ai-workstation/containers/bin/wsctl up all
~/.config/security-ai-workstation/containers/bin/wsctl status
```

For Rancher Desktop, chezmoi selects the Moby engine and disables Kubernetes by default because Compose and Testcontainers require the Docker API.

Services:

- PostgreSQL with pgvector
- Redis
- Qdrant
- MLflow

Scanner wrappers:

- ZAP baseline scan
- Semgrep
- Trivy
- Syft
- Grype
- Checkov
- Prowler using explicitly exported short-lived AWS credentials

Mutable source tags are resolved to immutable repository digests before Compose
or wrappers use them.

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

Read every profile and every script before use. Homebrew casks, container images,
VS Code extensions, MCP servers and coding agents all extend the trusted
computing base.
