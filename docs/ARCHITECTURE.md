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
lifecycle. This repository does not deploy a shared workstation stack of services.

What it does provide is the **substrate** beneath them (ADR-037): the selected
runtime — Colima by default — plus one Docker network with a pinned subnet, a shared
image registry and a persistent BuildKit builder. `script/container-substrate` owns
those idempotently.

The line between the two is **state**. Substrate holds none: a network, an image
cache, a build cache, each rebuildable from nothing. Services hold data, and they
stay project-local. That is what keeps ADR-010 intact rather than widened, and
`container-substrate` creates no service.

Every host port the substrate publishes binds `127.0.0.1`. A Docker port mapping
without a host part binds `0.0.0.0`, which would put an unauthenticated image
registry on every network this laptop joins.

Clusters are project-owned too. A `k3d.yaml` belongs in the project repository,
because the k3s version, the pod and service CIDRs and the ingress ports are all
project decisions, and CIDRs cannot be changed after a cluster is created.

### Containerised agent tools

A third case sits between the two above, and ADR-043 names it rather than leaving
it to be filed wrongly. An agent tool such as OpenHands is not a project's service —
no project owns it — and it is not substrate either, because it keeps conversations,
settings and provider credentials in `~/.openhands`.

`agent-tools/*.lock` pins the image and `script/ai-agent` runs it, under four
conditions the test suite enforces: addressed by digest and never by tag, every
published port bound to `127.0.0.1`, no `/var/run/docker.sock`, and exactly one state
directory plus one project mount.

The isolation is real, so it costs something. The agent uses the container's
toolchain, not the host's — Python and Node are in the image, Go, Java and Rust are
not — and it never sees the host's Git identity, credentials or signing key, so its
commits are unsigned and pushing happens from the host.

The directory is `agent-tools/`, not `containers/`: that name is reserved by
`tests/placement-policy.sh` for the shared compose stack ADR-010 refuses.

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

Hooks run in filename order, and the numbers are the ordering mechanism rather than
decoration — hook 12 precedes 15 because cloning over ssh and signing commits both depend on
a key existing.

```text
bootstrap
  -> installs the Command Line Tools (softwareupdate; GUI installer as fallback)
  -> installs Homebrew, after printing the installer's SHA-256
  -> installs trust set
  -> prompts for the git identity
  -> enables the application firewall (default; --no-hardening opts out)
  -> writes chezmoi data choices
  -> chezmoi apply
       -> before_10  renders the Brewfile from profiles, installs host packages
       -> after_12   generates this machine's ssh key, unless 1Password holds them
       -> after_15   restores the age identity from Bitwarden, or mints and flags one
       -> after_20   installs the mise-managed runtimes
       -> after_25   reports the container substrate; never starts it
       -> after_26   installs tart from the pinned release, unless running in a VM
       -> after_28   installs the declared kubectl plugins via krew
       -> after_30   reports the account login shell against the selected one
       -> after_35   installs the pinned VS Code extensions when dev is selected
       -> after_40   applies declared macOS defaults (default; --no-macos-defaults opts out)
       -> after_45   provisions browser profiles when selected
       -> after_90   prints the manual-security reminder
```

The two identity hooks are deliberately asymmetric. An age key is **restored**, because
files encrypted to an identity you no longer hold are unreadable, so a second identity is
data loss. An ssh key is **generated per machine** and never moved, because a signing key is
simply enrolled again. `script/identity` reports on both, and `script/verify` calls it
non-fatally — identity is the part of a machine this repository deliberately cannot
reproduce.

Chezmoi apply hooks reach back into the repository for scripts. `.chezmoiroot`
resolves `.chezmoi.sourceDir` to `<repo>/chezmoi`, so those paths must be built
with `dir .chezmoi.sourceDir`. `tests/chezmoi-templates.sh` enforces this and
executes every template, including the macOS-only branches, on Linux CI.

## The test VM is not an execution domain

`vm/` and `script/vm` provide a disposable macOS guest for testing this repository
against a pristine machine (ADR-036). It is **repository infrastructure, not a fifth
execution domain**, and the distinction matters because the `lab` profile also
provides VMs:

| | `lab` profile (Lima, UTM) | `script/vm` (Tart) |
|---|---|---|
| Purpose | isolate hostile work from the host | prove `./bootstrap install` works |
| Guest | Linux | macOS |
| Owned by | the four-domain model above | the validation suite |

Nothing in the placement matrix should ever route work to the test VM. It exists to
be destroyed and rebuilt, holds no credentials, and its contents are asserted to be
pristine before every run.

Its blind spots are recorded in `TASKS.md` rather than left for a reader to
discover, and one of them depends on which machine you are standing at. Nested
virtualization requires M3 or later: on the M1 Pro build machine no container
runtime runs inside the guest, so the container-runtime apply hook cannot be
exercised there, while on the M5 Max target it can. That is detected by
`nested_virtualization_supported` rather than assumed, because a flat "cannot"
would be false on the target and would go stale silently. Apple's licence permits
two macOS guests per host on both, so selections are tested sequentially.

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
