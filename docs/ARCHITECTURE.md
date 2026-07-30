# Architecture

## Objective

Provide a reproducible Apple Silicon workstation while keeping the macOS host
small, auditable and capable of using hardware and operating-system features
that Linux containers cannot provide.

## Execution domains

### macOS host

Owns native GUI, identity, system and frequently invoked tooling. Packages stay
here only when they need macOS APIs, direct host interfaces, system extensions,
interactive desktop use or low-latency access to the host filesystem.

Hardware-backed identity, when selected, is host-only by necessity: YubiKey
management, age identities on a YubiKey, Secure Enclave SSH keys and commit
signing all need USB, PC/SC or Secure Enclave access that a Linux container on
macOS cannot be given. Backup tooling is host-only for the same reason: it must
read the real home directory and reach off-site storage.

Browser identities remain host-local application state. Chrome and Firefox
installations use separate managed data roots rather than sharing cookies,
extensions and local storage between personal and work contexts. The
provisioning gate in `run_onchange_after_45_configure-browser-profiles.sh.tmpl`
must name every profile that declares a browser cask; the test suite derives
that set from `profiles/` so a browser cannot be moved and left unisolated.

### Project-local MLX environments

Each project that needs MLX owns it in a uv environment. This boundary preserves
Apple unified-memory and Metal-backed execution while avoiding global Python
dependency sprawl. MLX-LM, notebooks and serving tools are added only where a
project requires them.

### Project containers

Each project owns its Compose files, service versions, scanners, volumes and
lifecycle. This repository provides only the selected Docker-compatible runtime
and does not deploy a shared workstation stack.

### Isolated Linux VM

Provided by the `lab` profile: Lima for scriptable Linux VMs, UTM for GUI VMs
and x86_64 emulation. Before that profile existed this domain was declared but
had no implementation, so the placement matrix directed dangerous work to a
boundary that was not installed (ADR-027).

Owns high-risk or Linux-specific work:

- GDB/GEF/pwndbg
- pwntools and exploit development
- malware analysis
- untrusted binaries
- x86-specific testing

## Configuration flow

```text
bootstrap
  -> installs trust set
  -> writes chezmoi data choices
  -> chezmoi apply
       -> renders Brewfile from profiles
       -> installs host packages
       -> creates an age identity if none exists
       -> configures runtimes
       -> applies declared macOS defaults when requested
       -> provisions browser profiles when selected
```

Chezmoi apply hooks reach back into the repository for scripts. `.chezmoiroot`
resolves `.chezmoi.sourceDir` to `<repo>/chezmoi`, so those paths must be built
with `dir .chezmoi.sourceDir`. `tests/chezmoi-templates.sh` enforces this and
executes every template, including the macOS-only branches, on Linux CI.

## Verifying applied state

The repository declares intent; three commands report what is actually true of
the machine:

- `script/verify` — the declared packages are installed and chezmoi is healthy.
- `script/macos-defaults --verify` — each declared default was accepted rather
  than silently ignored by this macOS version.
- `script/hardening-check --strict` — host security state, exiting non-zero on
  failure so it can gate work.

`script/snapshot` records the observed state for later comparison.

## Trust boundaries

- The bootstrap fetches only the official Homebrew installer as its remote
  bootstrap operation.
- Homebrew packages and casks expand the trusted software set and must be
  reviewed as code-execution dependencies.
- Project container images remain untrusted execution dependencies and should
  be pinned and reviewed within the owning project.
- Chezmoi apply scripts can execute commands as the user and therefore require
  review through `chezmoi diff` and repository review.

Operational procedures for these boundaries are defined in `OPERATIONS.md`.
