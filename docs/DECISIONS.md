# Architectural decisions

## ADR-001: Use chezmoi as the configuration engine

**Status:** accepted

Chezmoi provides templating, machine-specific data, idempotent scripts and a
reviewable diff/apply boundary without introducing Nix as a second operating
system package model.

## ADR-002: Use a minimal Strap-inspired bootstrap

**Status:** accepted

The bootstrap installs only the initial trust set and applies conservative
screen-lock/firewall controls. It does not copy Strap's Desktop recovery-key
handling, automatic FileVault activation or broad system mutation.

## ADR-003: Keep the macOS host minimal, not empty

**Status:** accepted

Tools requiring native GUI, Keychain, display APIs, raw host networking,
system extensions or low-latency filesystem interaction stay native. Services,
databases and repeatable scanners belong to the project that uses them.

## ADR-004: Keep MLX dependencies project-local

**Status:** accepted

MLX is a Python dependency, so each project that needs it declares `mlx` in its
own uv environment. The workstation does not deploy a shared `native-ai`
environment or controller. MLX-LM, notebooks and serving tools are
project-specific additions; any development server must bind to loopback by
default and must not be presented as production-safe.

## ADR-005: Use Rancher Desktop with Moby as the free default runtime

**Status:** accepted

Moby provides the Docker API required by Compose and common development tools.
OrbStack is the paid alternative; Colima is the CLI-only alternative. Only one
runtime should be active.

## ADR-006: Use immutable image digests for execution

**Status:** accepted

Project repositories own image selection and should resolve mutable upgrade
inputs to reviewed immutable digests. This workstation repository does not
provide an image controller or shared scanner wrappers.

## ADR-007: Install BetterDisplay natively

**Status:** accepted

Display discovery, HiDPI scaling, DDC brightness and macOS display control
require host integration and are not meaningful container workloads.

## ADR-008: Use `just` as a thin command UX, not an implementation layer

**Status:** accepted

The repository orchestrates named workflows rather than incremental file
builds. Shell scripts remain canonical; `justfile` recipes delegate to them.

## ADR-009: Use hierarchical AGENTS.md plus repo-local Codex skills

**Status:** accepted

Root instructions define global invariants; nested files narrow constraints by
directory. Skills provide progressive-disclosure workflows for broad
maintenance and tool-placement tasks.

## ADR-010: Keep service dependencies project-local by default

**Status:** accepted

Databases, queues, vector stores, scanners and similar dependencies are declared
in each project's own container configuration rather than run as a global
workstation stack. This keeps versions, configuration, data lifecycle and
teardown coupled to the project that owns them. The workstation repository does
not maintain or deploy a shared container stack.

## ADR-011: Do not depend on Ruby in repository automation

**Status:** accepted

Repository scripts, validation and CI do not install or invoke Ruby. Generated
Brewfiles are checked against the deliberately restricted `brew` and `cask`
entry syntax using Python, which is already required by the validation suite.
Homebrew Bundle may use Homebrew's own bundled Ruby internally; that is an
implementation detail of the selected host package manager, not a repository
runtime dependency.

## ADR-012: Keep hazardous and stateful capabilities out of the baseline

**Status:** accepted

The initial workstation does not run multiple container runtimes
simultaneously, install native PostgreSQL, Redis or Qdrant daemons, enable
FileVault automatically, export recovery keys or install Rosetta automatically.
These exclusions preserve explicit trust and execution boundaries and therefore
belong in the decision record rather than the operational backlog.

## ADR-013: Keep the default profile small and specialist capabilities opt-in

**Status:** accepted

The default installation selects only `core`, `dev`, `security` and the minimal
`productivity` profile. Cloud providers, Kubernetes, data clients, privileged
security monitors and personal productivity applications use explicit profile
fragments. This prevents unrelated credentials, background components,
permissions and update surfaces from entering the default trusted computing
base while keeping reviewed specialist tools reproducible.

## ADR-014: Isolate browser contexts with separate data roots

**Status:** accepted

When `productivity-extra` is selected, the workstation provisions `personal`
and `work` data roots for both Chrome and Firefox Developer Edition. A
repository-owned launcher passes the supported browser command-line options
instead of editing browser-owned profile registries or preference databases.
Additional contexts are explicit. Browser account sync remains a user decision
because signing multiple contexts into the same sync account can weaken the
intended separation.

## ADR-015: Permit single-binary scanners on the host as an opt-in profile

**Status:** accepted

ADR-010 keeps repeatable, CI-equivalent scanning inside each project's own
containers, and that remains the rule for anything reproducible. The
`security-scan` profile additionally permits a specific class of tool on the
host: single static binaries with no daemon, no persistent state and no
privileged access, used interactively to inspect an artefact before deciding to
trust it.

`trivy`, `syft`, `grype`, `osv-scanner`, `trufflehog`, `hadolint` and `dive`
qualify. Anything requiring a service, a database, credentials or elevated
privileges does not, and stays in the project container.

The profile is opt-in and is not part of the default selection.

## ADR-016: Declare macOS defaults in a table and verify them by read-back

**Status:** accepted

macOS silently ignores `defaults` keys it no longer honours: the write succeeds,
the value is stored and nothing changes. A write-only script cannot distinguish
"applied" from "accepted and ignored", and the set of ignored keys changes with
every macOS release.

`script/macos-defaults` therefore declares each setting once as
`section|scope|domain|key|type|value` and drives `apply`, `--dry-run`, `--diff`
and `--verify` from that single table. `--verify` reads every value back and
exits non-zero on drift, so `script/hardening-check` can gate on it and the
keys this macOS version ignores become a recorded, reviewable list.

Previous values are recorded before the first write so changes are reversible.
Privileged writes are listed and confirmed as a group rather than elevating
silently. Keys protected by TCC, such as the Safari domain, are reported as
unreadable rather than treated as failures.

## ADR-017: Sign commits with OpenPGP by default, and split work identity

**Status:** accepted

Commit signing is configured but disabled until a key is supplied, so the
default installation is unchanged.

`gitSigningMethod` selects the mechanism. **`gpg` is the default.** OpenPGP is
what the user asked for, it is verified by every forge without extra
configuration, and it extends to a key held on a hardware token without changing
the Git configuration. `gnupg` and `pinentry-mac` are in the `core` profile;
host placement is required because gpg-agent needs a GUI pinentry and, for a
smartcard key, direct USB access a container cannot be given.

`~/.gnupg` is managed with chezmoi's `private_` prefix so the directory is 0700;
gpg refuses to run otherwise. `gpg.conf` sets long key IDs and full
fingerprints, because short IDs are trivially collidable and must never identify
a key, and disables automatic key retrieval so fetching a key stays a deliberate
trust decision rather than a side effect of verifying a signature. gpg-agent
caches a passphrase for 30 minutes idle and 8 hours maximum, which is long
enough for a session but stops an unattended unlocked machine from signing
indefinitely.

gpg-agent does not serve SSH keys. `~/.ssh/config` uses the macOS agent or the
password manager's agent, and running two SSH agents makes it ambiguous which
key answers a request.

The `ssh` method remains available for a key held by 1Password, Secretive or a
YubiKey resident key, verified through an `allowedSignersFile`. That file is
emitted only for the `ssh` method; under `gpg` it is not consulted by Git.

Git identity is split by directory with `includeIf gitdir:`, mirroring the
`personal` and `work` browser data roots established in ADR-014. The same
isolation reasoning applies: contexts that should not be conflated should not
share an identity by default.

## ADR-018: Own backup in the repository rather than leaving it manual

**Status:** accepted

Encrypted, verifiable, off-site backup is a security control, not a
convenience, and leaving it entirely manual meant it stayed undone. The
`backup` profile installs `restic` and `rclone`, with the runbook in
`docs/OPERATIONS.md`.

Host placement is required: these tools read the real home directory and reach
external and off-site storage, which a project container deliberately cannot do.
They supplement encrypted Time Machine rather than replacing it. Scheduling
remains explicit and opt-in; this repository does not install a background agent
without the user asking.

## ADR-019: Allow Touch ID for sudo, opt-in, through `sudo_local`

**Status:** accepted

Touch ID for `sudo` reduces password exposure to shoulder-surfing and keyloggers
during frequent privileged operations. It is enabled only by the explicit
`./bootstrap install --with-touchid-sudo` flag and never by default.

The implementation writes `/etc/pam.d/sudo_local`, which Apple provides for
exactly this purpose and which survives macOS updates. Editing `/etc/pam.d/sudo`
directly is not done: system updates overwrite it, which can silently remove the
configuration or, worse, leave a broken PAM stack.

## ADR-020: Deliberate exclusions from the desktop and tap surface

**Status:** accepted

These were evaluated and rejected for the baseline, recorded here so they are
not silently reconsidered:

- **Santa** (binary allowlisting): a system extension that needs a rule
  management and distribution story. Valuable, but it is a fleet control, not a
  single-workstation default.
- **Karabiner-Elements**: installs a DriverKit extension that observes all
  keyboard input. That is a material expansion of the trusted computing base for
  a remapping convenience.
- **AeroSpace** and **tflint**: available only from third-party taps. Adding a
  tap extends the trusted software supply chain beyond homebrew-core and
  homebrew-cask, and needs its own decision rather than arriving as a
  side effect of wanting one tool.
