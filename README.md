# mac-security-ai-workstation

A secure, reproducible Apple Silicon workstation baseline for software
engineering, security engineering and project-local MLX workloads.

The project name is independent of the directory it is checked out into; every
command resolves its own repository root.

The target is an Apple Silicon MacBook Pro with 128 GB unified memory, 4 TB
storage and macOS on `arm64` — an M5 Max.

It is built and tested on a second Apple Silicon machine, an M1 Pro with 32 GB.
Both are `arm64`, so unlike the Intel development platform this replaces (ADR-034,
superseded) the build machine differs from the target only in capacity and
generation, not in architecture. Two consequences are worth knowing before reading
test results, and both are detected rather than assumed:

- The M1 Pro cannot nest virtual machines, so a container runtime cannot be
  exercised inside the test VM there. The M5 Max can.
- The test guest is sized for the smaller machine by default.

See [ADR-036](docs/DECISIONS.md).

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

**On a brand-new Mac, start at [docs/NEW-MACHINE.md](docs/NEW-MACHINE.md).** It covers what
this section assumes you already have — a checkout, the Command Line Tools, and an identity —
and separates the two starting points that get confused: adding a Mac while keeping the one
you have, where only GPG material needs carrying across, and retiring the machine you are
replacing, where a list of things must be rescued first.

From nothing:

```bash
mkdir -p ~/workspace/istvano
git clone https://github.com/istvano/setup-dev-mac.git ~/workspace/istvano/setup-dev-mac
cd ~/workspace/istvano/setup-dev-mac
./bootstrap plan && ./bootstrap install
```

The repository is public, so cloning needs no authentication — which matters on a machine
that has no SSH key yet. Choose the checkout location deliberately: `./bootstrap` records it
as `sourceDir` in `~/.config/chezmoi/chezmoi.toml`, and moving it later breaks every apply.

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
  --profiles core,dev,security,productivity,backup,kubernetes \
  --shell zsh \
  --runtime colima \
  --password-manager bitwarden \
  --firewall lulu \
  --git-name "Your Name" \
  --git-email "you@example.com"
```

The declared macOS defaults and the application firewall are applied by default.
Opt out with `--no-macos-defaults` or `--no-hardening`; `--with-macos-defaults`
and `--with-hardening` are still accepted and now redundant.

Optional identity and privilege choices, all disabled by default:

```bash
  --git-signing-method gpg                  # gpg (default), ssh or none
  --git-signing-key "0xABCD1234..."         # GPG key ID, or an SSH public key
  --work-git-dir "~/work"                   # directory using a work identity
  --work-git-email "you@employer.example"   # identity used inside it
  --with-touchid-sudo                       # Touch ID for sudo via sudo_local
```

The default free choices are zsh, Colima, Bitwarden and LuLu.
OrbStack, 1Password and Little Snitch are paid alternatives. Rancher Desktop
remains selectable as a GUI runtime, and fish is the alternative interactive
shell (see [Interactive shell](#interactive-shell)).

Follow [Operations](docs/OPERATIONS.md) for the complete first-install,
verification, update, hardening and package-reconciliation procedures.

## Package profiles

**[docs/TOOLS.md](docs/TOOLS.md) is the full catalogue** — every package, what it is
for, and whether it is a formula or a cask. It is generated from the purpose comments in
`profiles/*.Brewfile` by `just tools`, and the test suite fails if it drifts.

Host packages are defined by composable Brewfile fragments:

- `core`: bootstrap trust set, terminal, editor, Git and frequently used CLI
- `dev`: editors, coding agents and local validation — shell, YAML, Actions,
  Dockerfile and image scanning
- `security`: the general TLS and cryptographic toolkit
- `productivity`: BetterDisplay, required for DDC monitor input switching, and Obsidian
- `cloud`: OpenTofu, Terragrunt and module documentation
- `cloud-aws`, `cloud-azure`, `cloud-gcp`: provider-specific control-plane CLIs
- `kubernetes`: Kubernetes control-plane and interactive operations, including krew and
  the declared kubectl plugins (`images`, `sniff`, `whoami`, `neat`, `tree`,
  `view-secret`) installed by apply hook 28
- `data`: embedded SQL CLIs and native database/API clients
- `security-extra`: host-network and PKI tooling, interception proxies, and macOS
  microphone/camera and per-process network monitors. Hardware-key tooling — `ykman`,
  `age-plugin-yubikey`, Secretive — is present as commented-out lines, evaluated but not
  installed, so selecting this profile gives you none of it
- `security-scan`: the wider single-binary scanner set — SBOM, lockfile and
  credential scanning, image layer inspection (see ADR-015, ADR-040)
- `backup`: restic and rclone for encrypted, verifiable off-site backup
- `lab`: Lima, UTM and Ansible — the isolated Linux VM domain and local lab
- `docs`: d2, pandoc and draw.io for diagrams and stakeholder documents
- `fonts`: Nerd Fonts, including the symbols-only font usable as a fallback
- `mcp`: the official MCP inspector, for reviewing a server before trusting it
- `local-llm`: LM Studio, the one permitted local inference runtime (ADR-025)
- `productivity-extra`: optional browsers, VPN, notes, media and desktop
  utilities
- `paid`: non-alternative paid additions

The default profiles are `core,dev,security,productivity,backup,kubernetes`, which
install 70 packages with zsh, or 69 with fish — which is the ceiling
`tests/render-brewfile.sh` enforces, with no headroom left, so the next addition has to
argue for raising it (ADR-013). Kubernetes is in the default because
this workstation exists for Docker and Kubernetes development, so a default that
cannot do it is incomplete rather than lean (ADR-038). The default carries one tool per job (ADR-022) and no language
runtime from Homebrew: Node, Go, pnpm, Rust, Python and the JVM set — two JDKs plus Maven,
Gradle and Kotlin — all come from mise (ADR-021, ADR-042), and any other
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

Colima is the default runtime: a CLI-managed Linux VM on Virtualization.framework
exposing the standard Docker socket. It replaced Rancher Desktop, whose costs were
structural — a desktop GUI, a bundled Kubernetes control plane this configuration
disabled anyway, an idle-CPU issue on Apple Silicon, and a PATH strategy that
rewrites the shell files chezmoi owns. Rancher remains selectable; OrbStack is the
paid alternative. See [ADR-037](docs/DECISIONS.md).

Each project still owns its services, scanners, versions, volumes, ports,
credentials and teardown policy. What the repository owns is the **substrate**: the
tuned VM, one shared Docker network, a shared image registry and a persistent
BuildKit builder. All of it is stateless or a cache, which is the line ADR-037 draws
against the shared service stack ADR-010 declined.

```bash
just substrate          # create or reconcile it; idempotent
just substrate-verify   # non-zero when it has drifted
just substrate-status
```

The registry matters more than it looks: every k3d node has its own containerd
image store, so without a shared registry a second cluster re-pulls everything the
first already had.

Every host port the substrate opens binds to `127.0.0.1`, including the registry.
Omitting the host part of a Docker port mapping means `0.0.0.0`, which on a laptop
that joins untrusted networks is a real exposure rather than a theoretical one.

Clusters are per-project and are not this repository's business: keep a `k3d.yaml`
in the project repo so its shape is version-controlled. Pin the k3s image to your
production minor version, set non-default pod and service CIDRs before creation,
and remember that ServiceLB gives exactly one service per cluster ports 80 and 443
— which is Traefik, reached through Ingress, as in production.

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

Apple Silicon only. `require_supported_mac` fails on `x86_64` rather than warning,
because a platform the test workflow does not cover is a configuration nothing
verifies (ADR-036).

`/opt/homebrew` is the only Homebrew prefix, and `/usr/local` is deliberately not a
fallback: on Apple Silicon that path holds an x86_64 Homebrew installed under
Rosetta, so falling back to it would put a translated toolchain on `PATH` — working,
slower, wrong binaries, and silent about it. The prefix still has exactly one
definition, in `script/lib/common.sh`.

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
├── vm/                # The local macOS test VM and its pinned hypervisor
└── vscode/            # Declared VS Code extensions, pinned
```

## Development

Run the validation suite for every change:

```bash
./script/test
```

It covers shell syntax and shellcheck, shfmt, actionlint, gitleaks, Brewfile
rendering, profile-catalogue consistency, chezmoi template execution, YAML,
placement invariants, VM tooling, render idempotency, browser profiles and agent
context.

Five of those checks skip when their tool is absent — shellcheck, the
shfmt/actionlint/gitleaks set, chezmoi template execution, YAML, and the atuin config
parse, which needs a Python 3.11+ for `tomllib` that no profile declares. Three of the five
print "OK" while skipping, so a green local run reads as more coverage than it is. Require
them, which is what CI does:

```bash
REQUIRE_LINTERS=1 REQUIRE_CHEZMOI=1 ./script/test
```

## Testing a real install

`./script/test` is static validation and `./script/verify` inspects a machine that
is already installed. Neither can answer whether `./bootstrap install` turns a
pristine macOS into a configured workstation — and running it on this machine
answers that once, after which the machine is no longer pristine.

So the repository builds a disposable one. A golden macOS image is created from
Apple's IPSW, then cloned per run; `tart clone` is an APFS copy-on-write clone, so
a fresh guest costs a second rather than a reinstall (ADR-036).

```bash
./script/install-tart              # pinned release, digest and signature verified
./script/container-substrate       # the Colima VM, network, registry, build cache
./script/vm build                  # macOS from Apple's IPSW; interactive, once
./script/vm seal                   # prove the image is pristine AND usable
./script/test-install --runtime colima
```

[Testing a real install](docs/TESTING.md) is the numbered runbook, including the one
interactive step and what to do when a privileged cask stalls the run.

`./script/vm seal` refuses an image that is not both usable and pristine. The
second half matters more: a guest that already has Homebrew produces a green
install that never exercised the code path under test.

Because the `dev` profile installs shellcheck, shfmt, actionlint and gitleaks, the
guest is also where `./script/test` runs with nothing skipped;
`./script/test-install` does that automatically.

What the VM cannot prove is tracked in `TASKS.md` rather than left implied.
Nested virtualization needs M3 or later, so a container runtime cannot start in the
guest on the M1 Pro build machine — but it can on the M5 Max target, which is the
first machine anywhere that can exercise the container-runtime apply hook.
`script/test-install` detects which case applies rather than assuming, and defaults
to `--runtime colima`: the container runtime is most of what this workstation is for,
so a test that skipped it would be testing a machine nobody uses. On the M1 Pro the
packages install and the wiring is verified while the daemon cannot start, and the run
says so rather than passing quietly. Pass `--runtime none` to skip it. Apple's
licence permits two macOS guests per host on either machine, so a profile matrix
runs sequentially, and Ghostty needs Metal, which is unverified in a VZ guest.

See [vm/README.md](vm/README.md) and [Testing](docs/TESTING.md).

A remote arm64 Mac still works instead of the local VM:

```bash
export MAC_TEST_HOST=user@host MAC_TEST_PORT=22
./script/sync-to-mac ./script/test
```

`sync-to-mac` uses rsync rather than a clone, because a pristine macOS has no
`git` until the Xcode Command Line Tools are installed — the very thing under
test. It verifies that `.git` and the executable bits survived the transfer, since
both failures otherwise surface much later as unrelated errors, and it forwards the
remote exit status.

CI runs the suite twice: on `ubuntu-latest`, where bash 5 cannot prove macOS behaviour
under the bash 3.2 the target ships (ADR-033), and on `macos-latest`, which additionally
runs `./bootstrap plan`. Neither can boot a VM — hosted runners have no nested
virtualisation — so `script/vm` and `script/test-install` are exercised only locally.

Homebrew renames tokens continuously, and VS Code extension ids change too, so both
declared sets are checked against upstream separately. These are the only checks that need
network access, and both run weekly in CI:

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

[docs/MANUAL-SECURITY.md](docs/MANUAL-SECURITY.md) is the checklist — eleven items,
each with what to do, why it is not automated, and how to verify it. The last
apply hook points at it, and `./script/hardening-check` reports which are done.

## Trust model

Read every selected profile and every apply script before use. The Homebrew
bootstrap installer, packages, casks, project container images, editor
extensions, MCP servers and coding agents all expand the trusted computing
base.
