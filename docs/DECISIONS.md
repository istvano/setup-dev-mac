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
