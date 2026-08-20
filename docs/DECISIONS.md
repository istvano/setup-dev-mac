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

**Status:** superseded by ADR-037

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

BetterDisplay is a hard requirement rather than a convenience: this workstation
shares its monitors with a second Mac, and DDC input switching is how the
displays are moved between the two machines. Removing it removes the ability to
use both machines at one desk.

DDC support, brightness, volume, power and input switching are all free-tier
features, so no licence is required for this use case. Advanced keyboard
shortcuts are Pro-only, which matters only if input switching is to be bound to
a hotkey rather than driven from the menu bar.

Keyboard and pointer sharing between the two Macs is not a package decision:
macOS Universal Control provides it natively.

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

**Status:** accepted, amended by ADR-038.

ADR-038 moves `kubernetes` out of the specialist list and into the default set: this
workstation exists for Docker and Kubernetes development, so a default that cannot do
Kubernetes is incomplete rather than lean. The principle below is unchanged and still
governs cloud CLIs, data clients, privileged monitors and personal applications.

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

## ADR-021: Consolidate runtime management on mise

**Status:** accepted

Node, Go, Java, Rust and pnpm are declared in
`chezmoi/dot_config/mise/config.toml.tmpl`. Homebrew installs none of them.

Rust is the case that matters. mise manages Rust by driving rustup: it installs
rustup itself when absent and sets `RUSTUP_TOOLCHAIN` for the selected version.
A `brew "rustup"` alongside it is therefore not a second implementation but a
second *place the toolchain version is decided*, which is how a project ends up
building against a different compiler than the one its `mise.toml` names.

`uv` remains separate and stays in `core`. It is the Python package and
environment manager for project-local work, including MLX (ADR-004), and is not
competing with mise for the same responsibility.

This removes the rustup fix-up block from
`run_onchange_after_20_configure-runtimes.sh.tmpl` and the Homebrew rustup keg
from `PATH` in `dot_zshrc.tmpl`; `mise install` now provisions everything.

## ADR-022: One tool per job in the default profile

**Status:** accepted

The default profile carries exactly one tool for each job. Every entry is
software that executes on the host from first boot, so a second tool for the
same task is trusted code that buys nothing.

Removed, with the replacement that already covers the use case:

| Removed | Replacement |
|---|---|
| `htop` | `btop`, which shows the same process view plus CPU, memory, disk and network |
| `tree` | `eza --tree`, already aliased as `lt` in `dot_zshrc.tmpl` |
| `difftastic` | `git-delta`, already wired in as Git's pager and `diffFilter` |
| `wget` | the system `curl`, which the bootstrap and every repository script already use |

`tests/render-brewfile.sh` asserts both directions: each replacement is present
*and* each duplicate is absent. Asserting only the absence would let a future
change satisfy the rule by removing the capability instead of the duplicate.

Two exceptions are deliberate. `actionlint` depends on `shellcheck`, and `nmap`
depends on `openssl@3`; both are still declared explicitly. A tool that is
relied on directly should be declared directly, not acquired as a side effect of
another package's dependency graph, which can change without notice.

Two further carve-outs, stated rather than left to look like oversights:

- **AI coding agents are not one job.** `codex`, `claude-code` and `opencode`
  all sit in `dev`. They are not substitutes: each reaches a different model
  provider, and the plurality is the reason for having them. The rule targets
  redundant tools, not deliberate access to different backends.

  ADR-044 extended this to five, and the channel differs for each because the
  packaging does, not because the rule bent: `codex` and `claude-code` are casks,
  `opencode` a formula, `cline` an `npm:` tool declared in mise's config, and
  `aider` a pinned `uv` tool installed by chezmoi hook 29. None of the last two
  is in a Brewfile, and `tests/placement-policy.sh` asserts they stay out.
  OpenHands is a sixth, in a container, under ADR-043.
- **`curl` and `xh` coexist in `core`.** `curl` is what scripts and the
  bootstrap call and must not be removed; `xh` is for interactive API work,
  which is a daily task on this machine. Removing `xh` as a duplicate was the
  wrong call for this workload and was reversed.

Tools that are useful but not baseline stay in the profile commented out with
the reason, rather than deleted, so the evaluation is not repeated later. A
duplicate is deleted outright: leaving it commented invites reintroducing a
second tool for a job that is already covered.

## ADR-023: No pre-commit framework; `./script/test` and CI are the gate

**Status:** accepted

A `pre-commit` configuration briefly ran the lint and format checks on every
commit. It was removed after measuring it:

| Hook | Cost | Frequency |
|---|---|---|
| `tests/shell-syntax.sh` | 1633 ms | every commit |
| `tests/format.sh` | 815 ms | every commit |
| `script/test` | 5693 ms | every push |

Roughly 2.4 seconds per commit, and not constant: the format hook ran
`gitleaks detect` over the entire history each time, so the cost grew with every
commit ever made. The hooks also used `always_run` with `pass_filenames: false`,
so editing one comment re-linted every shell file in the repository.

The checks themselves are not in question — they run unchanged in
`./script/test` and in CI on every push, which is where a growing full-history
scan belongs. What was rejected is paying that cost on an operation as frequent
as `git commit`.

`brew "pre-commit"` is therefore not installed. If per-commit enforcement is
ever wanted again, scope it: `gitleaks protect --staged` is constant-time
because it reads only the staged diff, and shellcheck should receive changed
files rather than the whole tree.

## ADR-024: Keep continuously polling menu-bar agents out of the profiles

**Status:** accepted

`stats` was removed from `productivity-extra`. It polls hardware sensors
continuously to display a reading that `btop` produces on demand, so it is a
permanent background cost for an occasional need, and it duplicates a tool
already in `core` (ADR-022).

The same test applies to any future menu-bar utility: an agent that samples on a
timer forever must justify itself against running a CLI when the question is
actually asked. This does not apply to agents whose value *is* continuous
presence, such as the outbound firewall or the display manager.

## ADR-025: Permit one local inference runtime, in an opt-in profile

**Status:** accepted

`profiles/AGENTS.md` excludes Ollama, llama.cpp, PyTorch and Open WebUI from the
baseline. LM Studio bundles llama.cpp and MLX engines, so it falls under that
exclusion and is added only on explicit direction, as the maintainer skill
requires, and only in an opt-in `local-llm` profile. The default selection is
unchanged.

The exclusion was never about local inference being unwanted. It was about a
model runtime becoming an always-present, self-updating component of the
baseline. Confining it to an opt-in profile preserves that.

Three properties make this cask unlike anything else installed here, and they
are recorded because they are easy to forget:

- It self-updates. The cask carries `auto_updates`, so new code arrives without
  `brew upgrade` and never appears in `./script/update-report`. It is outside
  the reviewed update flow by construction.
- Its server must remain on loopback. The OpenAI-compatible endpoint defaults to
  `localhost:1234`; enabling "Serve on Local Network" would publish an
  unauthenticated inference endpoint, contradicting the serving invariant.
- The weights are the trust surface, not the application. GGUF and safetensors
  are data; pickle-backed `.bin` checkpoints execute code on load. Model
  publishers are a supply-chain dependency like any other.

The profile is named `local-llm`, not `ai`: `tests/placement-policy.sh` asserts
`profiles/ai.Brewfile` does not exist and refutes a bare `ai` token, which
enforces ADR-004's rule that there is no shared workstation AI environment.

Note that the placement test refutes the literal token `llama.cpp` and therefore
does not catch a bundled engine. The rule is stated here rather than left to a
check that cannot see it.

MLX placement is unchanged by this decision. It remains a project-local uv
dependency under ADR-004; `local-llm` installs a GUI application, not a Python
environment.

## ADR-026: Judge a candidate on maintenance, not popularity

**Status:** accepted

Three tools were proposed and evaluated together. Two were rejected on evidence
gathered before installing anything, and the rule they produced is recorded here
because star counts are the metric people reach for first and are the least
informative.

**Kap — rejected.** 19,300 stars, MIT, and effectively abandoned: last release
3.6.0 in October 2022, with one CI-config commit since. It bundles Electron
13.6.9, so its Chromium has had no security updates since 2021, and it holds
Screen Recording permission while doing so. Popularity measured a project that
was healthy years ago. CleanShot X in `paid` and the built-in Cmd+Shift+5 cover
the use case; `obs` is the free alternative if a non-paid recorder is wanted.

**Rockxy — rejected.** AGPL-3.0, 577 stars, but created in March 2026 with one
human contributor holding 448 of 453 commits, two watchers, 98 open issues and a
pre-1.0 version. It is also an intercepting proxy, so it would hold a trusted
root CA capable of decrypting every TLS session on the machine. That privilege
demands a maintenance story stronger than one person and four months. Replaced
by mitmproxy: MIT, 44,500 stars, commits landing daily, and no cask self-update
to bypass the reviewed upgrade flow.

**iTerm2 — accepted**, in `productivity-extra`. ADR-022 restricts one tool per
job to the *default* profile, so a second terminal is permitted opt-in. Ghostty
stays in `core` because the managed terminal configuration is written for it.

The checks that produced these decisions, in order of usefulness: date of the
last release (not the last commit — a CI tweak is not maintenance), number of
humans with meaningful commit counts, bundled runtime versions for anything
Electron-based, and whether the cask self-updates outside `brew upgrade`. Stars
came last and changed no outcome.

## ADR-027: Provide the isolated Linux VM the architecture already required

**Status:** accepted

`docs/ARCHITECTURE.md` and the placement matrix in
`.agents/skills/add-workstation-tool/references/placement.md` have always named
an isolated Linux VM as one of four execution domains, owning exploit
development, malware analysis, untrusted binaries, ptrace and GDB workflows, and
x86-specific testing.

No profile installed any VM tooling. For the repository's entire life the
placement matrix has been routing the most dangerous class of work to a boundary
that did not exist, which in practice means that work either did not happen or
happened somewhere less safe. Colima's VM is a container runtime and is not a
substitute: it exists to serve a Docker API, not to contain hostile code.

The `lab` profile closes this:

- **Lima** for the common case: scriptable, disposable Linux VMs declared in
  YAML, running arm64 guests on Virtualization.framework.
- **UTM** for what Lima cannot do: a GUI, non-Linux guests, and **x86_64
  emulation**, without which the architecture's x86-specific testing claim stays
  unmet. Emulation is slow, so it is a deliberate choice rather than a default.
- **Ansible** so lab machines are provisioned from source and can be destroyed
  and rebuilt rather than repaired.

The profile is opt-in. Two operating rules keep the boundary real rather than
nominal, and are documented in `docs/OPERATIONS.md`: no home, SSH or credential
directories are mounted into a lab VM, and snapshots are taken before running
anything untrusted and reverted afterwards. A VM that is continuously patched
in place is no longer isolated from what it has run.

## ADR-028: Add the product-management half of the toolchain

**Status:** accepted

The workstation was equipped for engineering and had almost nothing for the
product work done on the same machine: Obsidian for notes and no way to produce
a diagram or a document for someone who does not use a terminal.

The `docs` profile adds `d2` and `pandoc`, with `drawio` for GUI work.

Diagrams-as-code is preferred over a binary canvas for the same reason
infrastructure is code here: a `.d2` source reviews in a pull request, diffs
meaningfully, and outlives the tool that produced it. `drawio` is included
because some diagrams are genuinely faster to draw than to declare, and it works
offline, unlike the browser-based alternatives — but it self-updates outside
`brew upgrade`, so it does not pass through the reviewed update flow.

Figma, Miro, Notion and Linear were rejected: each is a browser application
wrapped in Electron, and the isolated browser contexts from ADR-014 already
provide access to them without adding a runtime to the trusted computing base.

## ADR-029: Manage MCP servers with an approved catalogue and container isolation

**Status:** accepted

An MCP server is arbitrary code holding tool access to the machine. The usual
way to run one is `npx -y some-package@latest`, which downloads and executes
unpinned remote code with full user privileges every time an agent starts. That
contradicts ADR-006 and the rule in `AGENTS.md` against unreviewed remote-script
execution outside the Homebrew bootstrap boundary. Config sprawl across four
agents is the visible problem; this is the actual one.

No single tool manages MCP. Enforcement, isolation and review are three separate
jobs, and the survey found one credible answer for each:

- `mcp-get` is archived upstream and deprecated in Homebrew.
- `mcpm` synchronises configuration across clients. It solves sprawl, not trust.
- Docker's MCP Gateway documents Docker Desktop 4.59+ as a prerequisite, which
  does not fit a Rancher Desktop workstation.

**Enforcement.** Claude Code's managed settings tier supports an approved
catalogue: `allowManagedMcpServersOnly` with `allowedMcpServers`, deployed to
`/Library/Application Support/ClaudeCode/managed-settings.json`. That tier
outranks user, project and local settings, so the catalogue cannot be widened
from a config file. `mcp/managed-settings.json` is the declared state and
`script/mcp-policy` installs and verifies it.

Two properties of the mechanism shape the design:

- **`serverName` is not a security control.** The name is a label the user
  assigns, so any server can be called `github`. `tests/mcp-policy.sh` rejects a
  `serverName` entry in the allowlist, because accepting one would look like
  enforcement while providing none.
- **`serverCommand` matches exactly**, every argument in order. That is the
  lever: allowlist a pinned command and every unpinned variant is refused. The
  test rejects `@latest` and unversioned package specs, which turns ADR-006 from
  a principle into a check that fails the build.

**Isolation, available but not deployed.** ToolHive runs each server in its own
container with minimal permissions and no local credentials, and works with any
Docker-compatible runtime, so Rancher's Moby qualifies. It is **not installed by
default**: nothing in the bootstrap, the profiles or the chezmoi apply path
brings it in. `script/install-toolhive` is an explicit, separate action, and it
fetches a release pinned by SHA-256 in `mcp/toolhive.lock` rather than using the
third-party tap that ADR-020 discourages.

It stays optional because it is pre-1.0, it depends on a running container
runtime, and it changes how servers are reached. Keeping it out of the default
path means the baseline does not acquire a pre-1.0 dependency that most sessions
never use.

Because it is optional, nothing else may assume it: `script/update-report` skips
the version check unless `thv` is actually installed, and `tests/mcp-policy.sh`
treats a missing lock file as valid rather than a failure.

**Review.** The `mcp` profile installs the official `mcp-inspector`, which shows
the tools a server actually exposes. Inspection happens before trust, not after.

### What the two controls cost each other

ToolHive exposes servers over HTTP on loopback rather than as stdio commands, so
a ToolHive-managed server is allowlisted by `serverUrl`, not `serverCommand`.
The allowlist therefore pins a port rather than a package version, and version
pinning moves into the container image ToolHive runs.

That is a deliberate trade, not an oversight: the allowlist entry becomes less
specific, and in exchange the server holds no host credentials and is cut off
from the host network. It is only an acceptable trade with a fixed port.
ToolHive assigns a random proxy port by default, and the only entry matching a
random port is a wildcard such as `http://127.0.0.1:*/*`, which would admit any
process listening on loopback. `tests/mcp-policy.sh` rejects a wildcard loopback
port and the runbook uses `thv run --proxy-port`.

### Stated limitations

**Enforcement covers Claude Code only.** Codex and opencode read their own
configuration and no allowlist mechanism for either could be confirmed from
their documentation; this decision does not claim one.
`script/hardening-check` asks for those two configs to be reviewed by hand and
says plainly that they are checked rather than enforced.

**Without ToolHive, the only control is the allowlist, and it covers one agent.**
That is the cost of leaving isolation optional, and it should not be discovered
later: a server started directly runs as your user, with your environment, your
credentials and your network. The allowlist governs *which* servers may load in
Claude Code; it does nothing to limit what one can reach once loaded, and it
does not apply to Codex or opencode at all. Reach for ToolHive when a server is
not fully trusted, needs credentials, or came from someone else.

**ToolHive is pre-1.0** (v0.41.0 at the time of writing). The lock file and the
update report are the compensating controls.

## ADR-030: Pin language runtime versions, and fix the shell keymap explicitly

**Status:** accepted

A line-by-line review of the managed dotfiles found several places where the
configuration did not do what its comments claimed. Two are recorded here because
the reasoning is durable rather than mechanical.

### Runtime versions are pinned

`mise` previously declared `node = "lts"`, `go = "latest"` and `pnpm = "latest"`.
Those float: the toolchain a project builds against can change with no edit to
any tracked file, which is the same objection ADR-006 raises about mutable image
tags and `tests/mcp-policy.sh` enforces against `@latest`. Applying the rule to
container images and MCP packages while exempting the compilers was inconsistent.

Runtimes are now pinned to explicit minor versions. Bumping one is a reviewed
edit. `rust = "stable"` is retained deliberately: mise delegates Rust to rustup,
where `stable` names a release channel that rustup resolves and records, not an
unpinned fetch.

**A reviewed edit is not the same as a reviewed edit that happens.** `go` sat at
1.25 until Go 1.27 shipped, at which point it fell outside Go's two-major support
window and stopped receiving security fixes — with no edit, no failure and no
report, because nothing compared the pin to anything. Pinning removes surprise
changes; it does not remove the obligation to look. `script/update-report` now
carries that check for every pin here, and asks each one the question its policy
actually poses: whether Go is still *supported*, whether `node` is still the active
LTS, whether the JDK list still contains the newest LTS.

### The zsh keymap is set explicitly

`bindkey -e` is now set. The zsh manual: *"If one of the VISUAL or EDITOR
environment variables contain the string 'vi' when the shell starts up then it
will be 'viins', otherwise it will be 'emacs'."* Because this configuration sets
`EDITOR=nvim`, the shell was silently starting in vi insert mode, and every
plugin binding was landing in a keymap nobody chose. A keymap should not be a
side effect of an unrelated variable.

### Ordering hazards now carry tests, not comments

Two defects were invisible because the result still worked:

- `fzf --zsh` initialised after `atuin init`, and both bind Ctrl-R, so the later
  one won and Atuin search was silently replaced. `tests/placement-policy.sh` now
  asserts the order.
- `Include ~/.ssh/config.d/*` sat below the `Host *` block. ssh uses the first
  value obtained for each keyword, so per-host overrides could never take effect,
  even though a comment invited them. The include now comes first.

A third case, found later in `dot_config/ghostty/config`, is the same lesson in
different clothing. `scrollback-limit` is measured in **bytes**, and Ghostty 1.4
renames it to `scrollback-limit-bytes` precisely because the units were
ambiguous. Set to `10000` as though it were a line count, it produced a 10 KB
scrollback buffer against the 10 MB default — wrong by three orders of magnitude,
while reading as entirely plausible. The comment justifying it was also wrong: it
claimed the limit kept history off disk, but Ghostty never writes scrollback to
disk.

The first fix was itself wrong, and in an instructive way. It switched to
`scrollback-limit-lines`, which says exactly what is meant — but that key arrives
in Ghostty 1.4 and `cask "ghostty"` installs 1.3.1, which rejects it as unknown.
Checking all 18 keys in the file against `Config.zig` at each tag found this: a
config written against the current documentation, for a version that is not the
one installed. Documentation describes the latest release; the cask decides what
runs.

The assertion in `tests/placement-policy.sh` is now on **magnitude rather than
key name**: a byte key must hold at least a megabyte, a lines key at most a
million. That catches the actual defect — a value plausible for the other unit —
which naming a key never could, and it stays correct after a 1.4 upgrade makes
the lines key available.

The general lesson, and the reason these are in a decision record: a
misconfiguration that still produces working behaviour will not be noticed by
use, so it needs an assertion. A comment describing intent is not a control — and
a comment can be confidently wrong, which is worse than no comment, because it
stops the next reader checking.

Where upstream provides a resolver, prefer it over reading the file:
`ghostty +show-config`, `ssh -G <host>`, `starship explain` and
`script/macos-defaults --verify` all report effective values after parsing,
precedence and compatibility renames. Every defect in this record would have been
visible in one of those outputs.

**But check what the resolver actually resolves.** `ghostty +show-config` reports
values after parsing, and that is all: it does not load a theme. The theme was
declared as `catppuccin-mocha`, in this repository's own naming style rather than
Ghostty's `Catppuccin Mocha`, and `+show-config` echoed it back without
complaint while Ghostty refused to start at all. `ghostty +validate-config`
resolves it and says `theme "…" not found`.

A resolver answers one question. Trusting it for a different one is how a check
comes to be believed without being right — the same shape as the checks in
ADR-033 that could not distinguish "not applied" from "not readable".

The font in the same file was wrong in the quieter way. `font-family` was
`JetBrainsMono Nerd Font`, and no such family exists: the cask installs only
monospaced variants, and `ghostty +list-fonts` exposes `JetBrainsMono Nerd Font
Mono`, `JetBrainsMono NFM` and their no-ligature counterparts. A bad theme stops
Ghostty starting; a bad font falls back silently to a default face, so the
terminal opens looking almost right. `+validate-config` passes either way.

Two names in one file, both written in this repository's naming style rather than
the one the tool uses, one loud and one silent. The loud one was found in
minutes. The silent one was found only because the loud one forced someone to
run `+list-fonts`.

## ADR-031: Offer fish as a mutually exclusive shell fragment, without reassigning the login shell

zsh is the default because macOS ships it, but the interactive shell is a
preference, not an architectural constraint. fish is offered as an alternative.

### Why a fragment, not a profile

The shell is a mutually exclusive choice, like the container runtime, the password
manager and the outbound firewall, so it uses the same mechanism:
`profiles/shell-zsh.Brewfile` or `profiles/shell-fish.Brewfile`, selected by
`--shell`. A profile would let both be selected at once, which is meaningless —
and worse, it would still work, so nobody would notice.

Selecting fish therefore *replaces* `zsh-autosuggestions` and
`zsh-syntax-highlighting` rather than adding to them. Those two formulae exist
only to give zsh what the fish reader already does natively, which is also why
fish needs one package where zsh needs two.

It is the only alternative with no `none`: a workstation always has an
interactive shell, so the fragment is appended unconditionally.

### No plugin manager, for either shell

fisher, oh-my-fish, Tide and the zsh frameworks all fetch code from GitHub at
runtime, outside the Homebrew trust boundary that `SECURITY.md` draws. Nothing
here needs them: the prompt is starship, history is Atuin, directory jumping is
zoxide and per-directory environments are direnv, and every one of those supports
fish directly. This is ADR-020 applied to shell plugins.

### The account login shell is not reassigned

Selecting fish sets Ghostty's `command` to run it. It does **not** run `chsh`, and
it does not add a line to `/etc/shells`.

This is the more defensive arrangement, not merely the more cautious one. A shell
configuration that fails to parse costs a terminal tab instead of the ability to
open a working login session, and zsh — which macOS guarantees is present —
remains what `$SHELL`, `ssh <host> <command>` and recovery mode get. Editing
`/etc/shells` also needs sudo, and this repository keeps privileged account
changes manual for the same reason FileVault and the Touch ID PAM entry are
manual: they are hard to reverse and they are the user's decision.

`chsh` is documented in `docs/OPERATIONS.md`, and a `run_onchange` hook reports
the divergence on every apply so it is visible rather than assumed. It is
`run_onchange` and not `run_once` because the selection is part of the script:
switching shells re-runs it, where a `run_once` script would stay silent through
exactly the change worth reporting.

### Two settings that are wrong in the ADR-030 way

Both were found by reading upstream sources rather than by using the result.

The Ghostty `command` line needs `--login`. fish applies
`/etc/paths` and `/etc/paths.d` only for a login shell — `status is-login && command
-sq /usr/libexec/path_helper`, in fish's own `share/config.fish` — and those files
are how macOS installers put themselves on `PATH`. Without `--login`, fish starts
normally and silently has a shorter `PATH` than zsh.

`fish_add_path` ignores a directory that does not exist, and says so only under
`--verbose`. `~/.local/bin` is on fish's `PATH` purely because chezmoi creates it
for `dot_local/bin`, whereas `.zshrc` prepends it unconditionally. If that
directory were emptied, zsh would keep the entry and fish would quietly lose it,
so `tests/placement-policy.sh` ties the two together.

The Control-R collision between fzf and Atuin is the same hazard as in
`.zshrc`: fish's fzf bindings run `bind \cr fzf-history-widget` and Atuin binds
Control-R too, so the later initialisation wins. The order is asserted for both
shells.

`.chezmoiignore` also gets an assertion. It has no `.tmpl` suffix, so the template
test's file selector cannot see it, and it fails open — a broken conditional
simply stops ignoring the target, which looks like nothing happening.

### What fish needs less of

Documented as absences in `config.fish`, because a missing setting otherwise reads
as an oversight: there is no `compinit`/`compaudit` (completions autoload, and
Homebrew's own fish formula "discovers Homebrew-managed completions
automatically"); no `HISTSIZE`, `SAVEHIST` or `SHARE_HISTORY` (history is unbounded
and shared by default, and a leading space already keeps a line out of it); no
`WORDCHARS` fix (Control-W is `backward-kill-path-component`, verified against
fish 4.8.1); and no `ZSH_HIGHLIGHT_MAXLENGTH` equivalent (highlighting and
autosuggestions are part of the reader, not sourced plugins).

What fish needs *more* of is a `status is-interactive` guard, because
`config.fish` is read by every fish process including non-interactive ones, and an
explicit `set -g fish_key_bindings`: that variable is conventionally universal, so
running `fish_vi_key_bindings` once at a prompt persists into every future
session. A global assignment shadows the universal one and keeps the reviewed file
authoritative — the same concern as the zsh keymap in ADR-030, reached by a
different route.

## ADR-032: Declare VS Code extensions with pinned versions; take Nerd Fonts from casks, not the upstream installer

Two additions with one shape in common: both install third-party content, and both
have an easy path that skips review.

### Extensions are the same trust problem as MCP servers

A VS Code extension is unreviewed third-party code running inside the editor
process, with the editor's filesystem access and network egress. The usual way to
install one is to click Install and take whatever the marketplace serves, then let
the editor update it silently forever.

`vscode/extensions.list` gets the answer ADR-029 already gave for MCP server
packages: an exact version on every entry, a stated purpose on every entry, and
`script/vscode-extensions` as the only thing that installs them. Version pinning
is enforced by `tests/vscode-extensions.sh`, which also rejects a commented-out
entry that would not parse if enabled — a trap that otherwise fires during an
apply rather than in CI.

`script/check-extensions` is the sibling of `script/check-tokens` and runs in the
same weekly workflow. A pin is a claim about an upstream registry, and it goes
stale without anyone touching this repository.

### Pinning depends on a setting this repository does not own

VS Code updates extensions itself unless `extensions.autoUpdate` is `false`. With
it on, every pin describes a version that was installed once rather than the one
running now, and the list becomes fiction while still looking maintained.

`settings.json` is a personal file and merging into it would be a destructive edit
of user-owned state, so the scripts do not write it. Instead `--verify` warns when
the setting is not `false` and reports drift regardless. A machine that ignores the
advice is noisy, not silently wrong.

### Only roots are declared

An extension pack installs its children. `ms-python.python` brings Pylance,
debugpy and the environments extension; `ms-toolsai.jupyter` brings four;
`remote-ssh` brings two; `vscode-docker` depends on Container Tools. Ten of the
sixteen declared entries' worth of extensions arrive this way.

Pinning a child would add a version moving on someone else's release schedule for
no benefit. But leaving them undeclared makes `--diff` report ten false
"undeclared" entries, and a diff nobody reads is not a control. So `--diff`
resolves pack membership from each installed extension's own `package.json` on
disk — local, authoritative, and impossible to leave stale, unlike a
hand-maintained table.

Nothing is uninstalled. An extension added by hand is reported and left alone,
the same treatment `script/update-report` gives Homebrew cleanup candidates.

### Nerd Fonts come from casks

The upstream project's `install.sh` clones a multi-gigabyte repository and runs a
remote script, which is outside the Homebrew trust boundary in `SECURITY.md`.
There is no need for it: the `font-*-nerd-font` casks are in `homebrew/cask`
proper — the `homebrew/cask-fonts` tap was merged and no `brew tap` is required,
so ADR-020 is satisfied — and each cask downloads the release archive from
`github.com/ryanoasis/nerd-fonts` with a pinned SHA-256. The result is the same
files through a reviewed, digest-verified path.

The `fonts` profile is opt-in and judged more leniently than the software
profiles, because a font executes nothing, opens no port and needs no permission.
It is still curated rather than complete: `homebrew/cask` carries 71 Nerd Font
casks, and installing all of them only makes the font picker unusable. The
symbols-only font earns its place on capability rather than taste — being glyphs
without an alphabet, it upgrades any unpatched font by fallback.

`font-jetbrains-mono-nerd-font` stays in `core` because
`dot_config/ghostty/config` names it, so the terminal depends on it whether or not
the profile is selected.

### Three failures found by building this, all of the ADR-030 kind

An unknown `font-family` is not an error in Ghostty: it falls back to a default
silently, and upstream carries a discussion titled "Setting the wrong font family
silently fails and the default font is used instead". The symptom is prompt and
`eza --icons` glyphs becoming replacement boxes — a configuration problem that
presents as a rendering problem. `tests/placement-policy.sh` now asserts the
font-family and the `core` cask as a literal pair. Deliberately not derived one
from the other: Homebrew's word splitting is not mechanical
("JetBrainsMono Nerd Font" is `font-jetbrains-mono-nerd-font`, "MesloLGS Nerd
Font" is `font-meslo-lg-nerd-font`), so any normalisation clever enough to pair
them is also wrong often enough to fail a valid change.

`comm` compares byte by byte while `sort` under a UTF-8 locale gives punctuation
no weight. `ms-vscode-remote.remote-ssh` and `ms-vscode.remote-explorer` therefore
sorted in an order `comm` did not expect, and `comm` warned on stderr but still
printed a result — one that listed the same extension as both missing and
undeclared. Every sort in `script/vscode-extensions` is `LC_ALL=C`.

Extension ids are case-sensitive as published, and `code --install-extension`
matches case-insensitively. `golang.go` therefore installs correctly and then
reports as permanently missing in `--verify`, because that compares text against
`--list-extensions`, which prints the published casing. `script/check-extensions`
reports the canonical casing as a failure rather than a note.

## ADR-033: The test suite must run on the target platform, not only in CI

Two defects found while reviewing before the first real install. Neither could
fail in CI, and both would have failed immediately on the Mac.

### macOS ships bash 3.2, and four test scripts required bash 4

Apple froze `/bin/bash` at 3.2.57 rather than ship GPLv3, and nothing here
installs a newer bash, so `#!/usr/bin/env bash` resolves to 3.2 on the only
machine this repository targets. `mapfile` arrived in bash 4.0.

`tests/shell-syntax.sh`, `tests/format.sh`, `tests/chezmoi-templates.sh` and
`tests/profiles.sh` all used it. Every one would have died with
`mapfile: command not found` on the first `./script/test` on the Mac, while
passing on bash 5 in Linux CI.

`bash -n` cannot catch this: a missing builtin is a runtime lookup failure, not a
syntax error. So the guard is a grep for bash 4 builtins in command position,
in `tests/shell-syntax.sh`, over the same file list the linters use. The
whole suite is now verified against bash 3.2.57 directly.

The general point: a test suite that only ever runs on the CI platform is
testing the CI platform. Where the target differs — bash version, BSD versus GNU
userland — the difference has to be either asserted or exercised. `stat` was
already handled this way, trying `stat -f` before `stat -c`; `mapfile` was not.

### chezmoi applied the repository's own documentation to the home directory

`chezmoi/AGENTS.md` is instructions for whoever edits the source state. chezmoi
makes no such distinction: every file under the source directory is a target, so
`chezmoi apply` wrote `~/AGENTS.md` containing that document. Nothing failed and
nothing warned — the home directory simply gained a file from the repository on
every apply.

It is now in `.chezmoiignore`, and `tests/chezmoi-templates.sh` requires every
managed file or directory target to be a dotfile, which catches the next
README, AGENTS.md or note added there for humans.

That test asks `chezmoi managed` rather than reading `.chezmoiignore`, for the
reason ADR-030 gives: whether a pattern excludes a path is chezmoi's decision,
and a grep for the pattern text only proves the text is present. The earlier
version of this test checked the rendered ignore file and would not have caught
the stray target at all.

### `command -v python3` is true on a machine where python3 cannot run

Found on the first run against a real Mac. `./script/test` reached
`tests/render-brewfile.sh`, which invokes `python3`, and macOS answered:

```
xcode-select: note: No developer tools were found, requesting install.
```

Before the Command Line Tools are installed, macOS ships **stubs** at `/usr/bin`
for `python3`, `git`, `clang` and others. Running one does not fail — it opens a
GUI installer dialog. Over SSH that is a command which appears to hang, with the
explanation on a screen nobody is looking at.

The damaging part is that `command_exists python3` returns **true** for a stub.
`script/check-tokens`, `script/check-extensions`, `script/setup` and
`script/vscode-extensions` all guarded on exactly that and would all have tripped
the installer anyway. A guard that cannot fail on the platform it was written for
is not a guard.

`xcode-select -p` reports the state without triggering anything; only
`xcode-select --install` opens the dialog. So `common.sh` gains
`developer_tools_installed`, `require_developer_tools` and `python3_available`,
and the four scripts use them instead. `script/test` checks once at the entry
point rather than in each of the five tests that need python3.

This is the same lesson as the two above, reached from a third direction: the
CI platform has a real python3 and no concept of a stub, so nothing about this
was visible until the code ran on macOS.

### The CI runner's Python is not the target's Python

Two more failures followed on the next run, from the same root: what ships with
`python3` differs by platform, and the suite assumed the richer one.

`tests/yaml.sh` preferred `yamllint` and fell back to PyYAML — but PyYAML is not
in the standard library and the Command Line Tools do not bundle it, so on a
freshly bootstrapped Mac neither exists. The fallback chain had no floor, and the
suite died on `ModuleNotFoundError: No module named 'yaml'` before the `dev`
profile that provides yamllint had been installed.

`tests/placement-policy.sh` used `tomllib`, which is Python 3.11+. The Command
Line Tools ship 3.9. Every CI runner has 3.11 or later, so this was invisible
too, and it would have failed two tests after the first one was fixed.

Both now fall back to a **skip that `REQUIRE_LINTERS=1` turns back into a
failure**, matching the contract shellcheck, shfmt, actionlint and gitleaks
already use. The distinction that matters is between "no parser available here"
and "the file is malformed": the TOML check uses an explicit sentinel exit code
for the former, because collapsing the two would let a broken config pass on
every machine without a parser.

The rule this yields: an optional dependency needs a floor, and the floor must
fail loudly under the flag CI sets. A chain of fallbacks ending in an unguarded
import is not a fallback chain — it is a hard dependency with extra steps.

## ADR-034: Discover the Homebrew prefix; support Intel as a development platform

**Status:** superseded by ADR-036.

Intel support was removed once the Apple Silicon machine existed and the test
workflow moved to a local arm64 macOS VM. The prefix-discovery half of this
decision survives in spirit — `brew_prefix` is still the single definition and
nothing hardcodes a path at its call site — but it now has one candidate, and
`/usr/local` is deliberately not a fallback because on Apple Silicon it means a
Rosetta x86_64 Homebrew. The reasoning below is kept as the record of why the
hardcoded prefix was a genuine bug.

Apple Silicon remains the target. Intel macOS is now supported so the workstation
can be built and tested before the arm64 machine exists — which is precisely when
finding the defects is cheap, and the alternative is discovering them on the
machine that is supposed to already work.

### Why the hardcoded prefix was a real bug, not a portability nicety

Homebrew installs to `/opt/homebrew` on Apple Silicon and `/usr/local` on Intel.
Twenty-one places named the first one directly, and almost all of them had this
shape:

```bash
if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
```

On Intel that guard is simply false. Nothing errors, nothing warns: Homebrew is
never put on `PATH`, and the failure arrives much later as "command not found"
for a tool that is in fact installed. This is the ADR-030 pattern again — a
configuration that keeps working while doing nothing.

`script/lib/common.sh` gains `brew_prefix` and `activate_homebrew`. Apple Silicon
is checked first, deliberately: a Mac carrying both a native arm64 install and an
x86_64 one reached through Rosetta must resolve to the native one, and reversing
the order would put a translated toolchain on `PATH` — working, slower, and
subtly wrong.

### Three mechanisms, because there are three different constraints

- **Shell configurations** resolve at shell start, so one file works on either
  architecture and nothing machine-specific is baked in.
- **Chezmoi apply hooks** share a `.chezmoitemplates/brew-shellenv` partial. Five
  hooks previously carried the same snippet; single-sourcing it means the next
  fix lands in one place.
- **Ghostty's `command`** is the exception: a terminal config is a static string,
  not a shell, so it cannot ask `brew --prefix`. It resolves at apply time
  through `.chezmoitemplates/brew-prefix`, which falls back to the Apple Silicon
  path when neither exists so the target platform stays correct.

`tests/placement-policy.sh` now rejects any script or template naming
`/opt/homebrew` without also naming `/usr/local`, and
`tests/chezmoi-templates.sh` checks what the Ghostty line actually renders to —
a broken template would leave `command = /bin/fish --login`, a path that exists
on macOS and is the wrong shell entirely.

### Intel is warned about, not silently accepted

`require_macos_arm64` became `require_supported_mac`, which accepts arm64 and
x86_64 and warns on the latter. The two are not equivalent and the difference is
worth stating every time: the prefix differs, and arm64-only casks such as
`lm-studio` cannot be installed at all. A silent pass would let someone conclude
from a green Intel run that the Apple Silicon machine is covered.

What Intel *can* validate is most of the repository: every script, every chezmoi
template, both shell configurations, the profile catalogue and the whole test
suite. What it cannot validate is the cask set and anything architecture-specific
— those still need the real machine, and `TASKS.md` keeps them open.

### The gap is declared, reported and verified rather than remembered

"Which parts can this machine not prove?" is a question that decays into folklore
if the answer lives in someone's head. So it is declared next to the package as an
`arm64-only` marker in its purpose comment, and three things use it:

- `script/platform-gaps` reports what the current architecture cannot install and
  names the profiles to leave out. Offline, so it costs nothing at plan time.
- `bootstrap` runs it at plan time and again before install, where it asks rather
  than refuses — everything outside those profiles still installs, and dropping
  them is the operator's call.
- `script/check-tokens` verifies every marker against Homebrew's own
  `depends_on arch` **in both directions**, on the weekly schedule it already
  runs. A missing marker makes the report silently incomplete, so an Intel
  install fails with a raw `brew bundle` error; a stale one makes it exclude a
  profile that would have installed. Both are failures.

`tests/profiles.sh` additionally checks that `platform-gaps` still recognises the
marker form, against a fixture rather than against `profiles/` — deriving the
expectation from the same files being checked makes the test vacuous, which the
first version of it was.

### One unwritable directory fails every package

Found on the first real Intel install: 70 of 108 dependencies failed, all with
the identical message.

```
Error: The following directories are not writable by your user:
  sudo chown -R istvano /usr/local/share/man/man8
```

Homebrew checks prefix writability *before* installing anything, so a single
root-owned directory fails the whole run rather than only the packages that would
write there. The count made it look like a broad breakage; the cause was one
directory.

This is an Intel problem in practice. `/usr/local` is shared with the system and
with other installers, any of which can leave a root-owned subdirectory behind.
`/opt/homebrew` belongs to Homebrew alone and is created owned by the installing
user, so the Apple Silicon target does not meet it.

`require_writable_homebrew` now runs before `brew install` in `./bootstrap` and
again in the package apply hook — the hook as well, because `./script/setup`
reaches it without going through bootstrap, and that is the command used to
re-apply after a fix.

It **reports and refuses**; it does not repair. `sudo chown -R` on a system
directory is the privileged, hard-to-reverse operation `AGENTS.md` keeps manual,
and who should own a directory under `/usr/local` is a judgement about the
machine rather than something a bootstrap may assume. The error names the exact
command, which is the same one Homebrew itself suggests.

## ADR-035: An apply hook reports its failure; it does not abort the ones after it

chezmoi runs scripts in order and stops at the first non-zero exit. Every apply
hook was therefore a single point of failure for every hook after it, and the
first real install demonstrated this three times.

**`brew bundle` exiting non-zero cost every dotfile.** Nine formulae have no
bottle on macOS 13 and their source builds fail, so the package hook — a
`run_before` script — failed, and chezmoi abandoned the apply before writing a
single file. The machine ended with 195 packages installed and no `.zshrc`, no
`.gitconfig`, no terminal configuration: the least useful of the available
outcomes, caused by packages nobody had asked to be essential.

**`rdctl` returning 500 cost the four hooks after it.** Rancher Desktop answered
`list-settings` while still starting up and then rejected the write. The hook
already handled "rdctl is not there" but not "rdctl is there and refused", so the
VS Code extensions, the macOS defaults, the browser profiles and the security
reminder were all skipped by a container-runtime preference.

The rule these produce: **an apply hook configures something, and failing to
configure one thing is worth reporting rather than abandoning everything else.**
Nothing is swallowed — `./script/verify` fails on `brew bundle check` until the
packages are resolved, and `script/macos-defaults --verify` reports defaults that
did not take. The drift is still caught; it is caught by the verification step,
which can report all of it, instead of by an apply that stops at the first
problem and hides the rest.

`run_once_after_15`, `run_onchange_after_30` and `run_once_after_90` are exempt:
they report or print and cannot meaningfully fail.

### Only one thing may manage PATH

Found in the same install. Rancher Desktop defaults to a `rcfiles` path
management strategy, which appends this to `~/.zshrc`:

```
### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/istvano/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)
```

That file is chezmoi's. So every apply reported `.zshrc` as modified outside
chezmoi's control and prompted to overwrite; overwriting removed the block,
Rancher re-added it on next start, and the prompt returned forever. Two managers,
one file, no resolution — and the injected line carries an absolute home path,
which is the kind of value this repository keeps out of configuration.

`run_onchange_after_25` now also sets
`--application.path-management-strategy=manual`, and both shell configurations
add `~/.rd/bin` themselves.

They **append** it rather than prepend. `~/.rd/bin` also contains `kubectl`,
`helm` and `docker-compose`, and the versions this repository declares through
Homebrew should win over whatever Rancher happens to bundle (ADR-022). Rancher's
own `docker`, `nerdctl` and `rdctl` are still found, because nothing else
provides them.

### An audit that could not see what it was auditing

`script/hardening-check` reported this among its failures:

```
[FAIL] You need administrator access to run this tool... exiting!
```

`systemsetup -getremotelogin` refuses without administrator rights by printing to
**stdout and exiting 0**. The check tested the exit status, so its `review`
branch for "cannot inspect" never ran: the refusal text landed in the variable,
failed the match for `Off`, and became the name of a failed check.

The noise was the smaller problem. Remote Login was **on** — the SSH session
doing the testing proved it — and the check never saw it. An audit that reports a
permission error as a finding is not merely untidy; it is silently not auditing,
which is worse than having no check at all because it looks like one.

It now matches the refusal text explicitly, and was exercised against all four
outcomes: refusal, `On`, `Off`, and the command being absent.

The general point, and the reason it belongs next to the others here: a command's
exit status is only usable as a signal once you have checked that it actually
sets one.

### The same fault, twice more, in the verifier built to prevent it

`script/macos-defaults --verify` exists because macOS accepts a `defaults write`
for a key it no longer honours (ADR-016). Its first run on real hardware reported
four unset keys and one mismatch. All five were faults in the verifier.

`read_setting` used `sudo defaults read` for system-scope keys. Reading
`/Library/Preferences` requires no privilege — only writing does — so the sudo
was unnecessary, and wherever sudo could not prompt the read returned empty and
was reported as **unset**: precisely the signal that means "macOS ignored this".

`action_firewall_logging_verify` matched the word `enabled`, while macOS answers
`Log mode is on`. The setting was applied correctly and reported as drifted
every time. `script/hardening-check` matched `enabled|on` and passed the same
machine, so two checks of one setting contradicted each other and neither was
obviously wrong.

Both are the ADR-030 pattern in the tooling rather than the configuration: a
check that cannot distinguish "not applied" from "not readable" reports
confidently and means nothing. After the fix, `--verify` reports every declared
setting in effect on macOS 13.7.8, with no sudo, over SSH.

### The test for this was wrong in a way that looked right

The first version matched the hook's last line against globs including `*fi*`,
intending "ends in a closing `fi`". `browser-profile` contains the letters `fi`,
so an unguarded hook matched and passed. The check reported OK on a file that had
just been broken deliberately.

It now uses anchored regular expressions, and every guarded hook was unguarded in
turn to confirm each one is individually rejected. A test that has never been
seen to fail has not been shown to work — which is the same argument ADR-030
makes about configuration, applied to the tests themselves.

## ADR-036: Test the repository in a local macOS VM; drop Intel entirely

**Status:** accepted. Supersedes ADR-034.

`./bootstrap install` is the most consequential code path here and the only one
nothing could exercise. `./script/test` is static validation. `./script/verify`
inspects a machine that is already installed. Neither answers the question the
repository exists to answer: does a pristine macOS become a configured
workstation? Running it on the real machine answers that once, after which the
machine is no longer pristine and the answer cannot be reproduced.

The workstation was built on Linux and validated against an Intel macOS VM reached
over SSH. That arrangement has now outlived its purpose: Apple Silicon hardware
exists, and an Intel result says nothing about it. `TASKS.md` carried roughly
fifteen items whose only blocker was "requires the target Mac".

### Two machines, one architecture

The target is an M5 Max with 128 GB unified memory and 4 TB storage. The
repository is built and tested on a second Apple Silicon machine, an M1 Pro with
32 GB.

This is the same shape as the Intel arrangement it replaces, with one decisive
difference: both machines are `arm64`. Intel could not prove anything about the
target because the architecture differed — a different Homebrew prefix, casks that
declare `arch: arm64`, different bottles. The M1 Pro differs only in capacity and
generation, so a passing result there is evidence about the target rather than
merely evidence about a stand-in.

Where the two machines genuinely differ, the difference is DETECTED rather than
written down. Nested virtualization is the live case and the reason this section
exists: a flat "the VM cannot test a container runtime" would be true of the build
machine and false of the target, and it would go stale silently on the machine
where it stops being true.

### A golden image, cloned per run

The test VM is discarded and re-cloned from a golden image before every run, so
each run starts from the same pristine state.

That cadence is only affordable because of copy-on-write. `tart clone` is an APFS
clone: "a cloned VM won't actually claim all the space right away. Only changes to
a cloned disk will be written." A fresh guest costs a second and almost no disk,
against roughly half an hour to reinstall macOS from an IPSW. Without a cheap
reset, "repeatable" degrades to "occasionally", and a first-install test that is
run occasionally is a first-install test that is run once.

### Why not Lima, which was already installed

Lima was the obvious candidate — it is in homebrew-core, it is already in the
`lab` profile, and it gained experimental macOS guest support in v2.1. It cannot
do this job, for a reason that is structural rather than a rough edge:

`limactl snapshot` is implemented over `qemu-img` and does not support the `vz`
driver. macOS guests on Apple Silicon **require** `vz`. So there is no snapshot
primitive for a macOS guest at all, and every destructive run would pay for a full
reinstall.

Three further limitations point the same way. Lima's macOS guest is not headless —
its own template sets `video: display: "default"` with the note that the installer
requires a display device, and the documentation states there is "no support for
turning off the video display". There is no automatic port forwarding. And
passwordless sudo is disabled, which an unattended install cannot answer.

Lima stays in the `lab` profile. It remains the right tool for the Linux guests
ADR-027 provisioned it for; it is simply not a macOS test harness.

UTM was also considered and rejected for this purpose: it is already a declared
cask, but creating a macOS guest is GUI-driven and `utmctl` is a thinner
automation surface than a from-clean install test needs.

### Why tart is pinned from its release, not tapped

tart is carried only by a third-party tap, which is exactly what ADR-020 declined
for AeroSpace and tflint. Rather than argue with that rule, this sidesteps it:
`script/install-tart` installs a pinned release verified against `vm/tart.lock`,
mirroring `script/install-toolhive` and `mcp/toolhive.lock`.

Three things make the tap the worse route, independently of ADR-020:

- Homebrew 6 refuses to load a formula from an untrusted tap at all, so
  `brew bundle` cannot install it without a separate interactive `brew trust`
  step. A package that needs a trust prompt cannot live in a Brewfile.
- The formula depends on a second tap formula, `softnet`, widening the tap surface
  for something this repository does not use.
- The release is already pinnable, and better than most: a single universal
  archive with an upstream-published `checksums.txt`.

The pin is stronger than the tap would have been. `vm/tart.lock` records the
version, the SHA-256 **and** the Apple Developer Team Identifier that signed
`tart.app`, and the installer refuses on any mismatch. The signature is not
decoration: the bundle carries `com.apple.security.virtualization` and
`com.apple.vm.networking`, and those entitlements are only valid while the
signature is intact — which is also why the whole `.app` is installed rather than
the executable copied out of it.

**Licensing:** tart is "Fair Source", not OSI open source. It is free for
individual and small-organisation use with paid licensing above a threshold.
Recorded here because the package rules in `AGENTS.md` require a licence
classification, and "on GitHub" is not one.

### Why the golden image comes from Apple's IPSW

`tart create --from-ipsw latest` installs macOS from Apple's own image. The
alternative — cloning a prebuilt `ghcr.io/cirruslabs/macos-*` guest — is faster and
arrives with SSH and passwordless sudo already configured.

It is also a third party's macOS underneath a test of this repository's security
baseline. The result would describe their image as much as this configuration.
Pinning it by digest would satisfy ADR-006 and still not fix that.

The cost is real and is accepted: a freshly installed macOS boots into Setup
Assistant, which no script may click. Building the golden image is therefore a
one-time interactive step per macOS release. `./script/vm build` prints the
checklist; everything after it is automated.

### `script/vm seal`

A golden image decides whether every later result means anything, so it is
verified by read-back before it is trusted — the same argument ADR-016 makes about
macOS defaults.

Both halves are checked, and the second matters more. A golden that is not
**usable** fails every run for a reason that looks like a repository bug: annoying,
but self-announcing. A golden that is not **pristine** is worse. If Homebrew or the
Command Line Tools are already present, the install still reports success while
never exercising the code path under test. That is a green result that proves
nothing, which is the failure mode this repository keeps legislating against.

### Intel support is removed, not merely untested

Keeping a platform the test workflow no longer covers would mean shipping a
configuration nothing verifies. So it is gone rather than deprecated:

- `script/platform-gaps` is deleted. It reported which declared packages the
  current architecture could not install; with arm64 the only target, the answer
  is always none.
- `require_supported_mac` fails on x86_64 instead of warning.
- `--profiles all` no longer subtracts anything, so it expands straight from
  `VALID_PROFILES`.
- The two-way `arm64-only` marker reconciliation is out of `script/check-tokens`,
  and the marker is out of `profiles/local-llm.Brewfile`. A cask declaring
  `depends_on arch: arm64` now installs everywhere this repository runs.

### `/usr/local` is dropped for a second reason

The obvious cleanup is to stop treating `/usr/local` as a Homebrew prefix because
it was the Intel one. There is a sharper reason to remove it rather than leave it
as a harmless fallback.

On Apple Silicon that path still exists whenever an x86_64 Homebrew has been
installed under Rosetta. A fallback would therefore resolve to a **translated
toolchain on exactly the machine where `/opt/homebrew` is missing** — it would
work, slowly, with the wrong binaries, and report success. The correct answer there
is "Homebrew is not installed", which is what an empty result says.

`brew_prefix` is still a discovery function with one definition, and the
`brew-prefix` template still exists so the prefix is not inlined at call sites;
both simply have one candidate now. `tests/placement-policy.sh` asserts the
removal cannot half-revert, matching on `/usr/local/bin/brew` — the executable
form a reintroduced fallback would use — rather than on the bare prefix, which now
appears only in prose explaining its absence.

### What this VM cannot prove

Recorded because a test harness that hides its blind spots is worse than one that
names them:

- **Nested virtualization depends on which machine you are standing at, so it is
  detected.** Apple's Virtualization.framework supports it only on M3 and later.
  The build machine is an M1 Pro and cannot nest, so no container runtime starts
  inside its guest and
  `run_onchange_after_25_configure-container-runtime.sh.tmpl` is unprovable there.
  The M5 Max target can, so on the target that hook becomes testable.

  This is a limit of one machine, not of the design, and writing it down as a flat
  "cannot" would have been wrong in the direction that matters — declaring
  something untestable on the machine where it finally becomes testable.
  `nested_virtualization_supported` in `script/lib/common.sh` reads
  `hw.optional.arm.FEAT_NV`, and `script/test-install` either warns that the
  runtime cannot work here or points out that it now can. `--runtime none` remains
  the default because the smaller machine is where most runs happen.

  The negative branch is confirmed on M1 Pro; the positive branch is a claim to
  verify on the M5 Max, and `TASKS.md` carries it as such.
- **Two guests per host.** Apple's licence permits two macOS VMs on one host. The
  golden image plus one running clone is exactly two, so a matrix of selections
  runs sequentially. This is a design constraint, not a queueing preference.
- **Ghostty is unverified in the guest.** It needs Metal, and whether
  paravirtualized graphics satisfy it is unknown. `TASKS.md` records the result
  rather than predicting it.
- **Guest sizing defaults to the smaller machine.** 8 GB RAM and 4 CPUs suit the
  32 GB build machine, not the 128 GB target; `WORKSTATION_VM_MEMORY_GB` and
  `WORKSTATION_VM_CPUS` raise it. The default fits the machine where most runs
  happen rather than the roomier one.
- **Setup Assistant is manual**, so a macOS release that changes it makes golden
  rebuild manual again.

## ADR-037: Colima as the default container runtime, with a declared substrate

**Status:** accepted. Supersedes ADR-005 and refines ADR-010.

Rancher Desktop was chosen as the free default because Moby provides the Docker API
that Compose and Testcontainers need (ADR-005). That is still true, and it is also
true of every alternative, so it never distinguished Rancher from anything. What
distinguished Rancher was its cost, and the cost was structural:

- **It fights the configuration.** Its default path-management strategy, `rcfiles`,
  appends an export block to `~/.zshrc` — a file chezmoi owns. chezmoi then reports
  the target as modified outside its control on every apply and offers to overwrite;
  overwriting removes the block, Rancher re-adds it on next start, forever. Hook 25
  existed largely to set that strategy to `manual`.
- **It cannot be configured without being running.** `rdctl` answers
  `list-settings` before it will accept a write, and returned 500 to a `set` while
  still starting. Hook 25 carried a sixty-iteration wait loop for this, and
  `TASKS.md` still listed the result as unproven.
- **It installs what this configuration then disables.** A bundled Kubernetes
  control plane, switched off; a desktop GUI, for a workflow driven from a terminal.
- **An idle-CPU issue on Apple Silicon**, on a machine where battery matters.

Colima has none of those. It is a CLI-managed Linux VM on Virtualization.framework
exposing the standard Docker socket: no GUI, no privileged background daemon, no
bundled control plane, and nothing that edits the shell files chezmoi manages.

Rancher remains selectable, so hook 25's Rancher branch is kept rather than deleted.
OrbStack stays the paid alternative — it is free only for personal or
non-commercial use, or under $10,000 a year of related revenue, so a workstation
used for employment needs a licence.

### Apple's `container` was evaluated and rejected, for now

Apple's native container tool reached 1.0 in June 2026 and is genuinely
interesting here: it runs each container in its own lightweight VM via
Virtualization.framework, which is *stronger* isolation than the single shared
Linux VM every Docker-compatible runtime uses, and would suit this repository's
threat model better than the incumbent.

It does not implement the Docker API. Anything that speaks to a Docker socket —
Compose, Testcontainers, kind, devcontainers — does not work with it, and the
community bridges are immature. `docs/ARCHITECTURE.md` requires that API for
project Compose stacks and CI-equivalent services, so this is a watch item and not
a candidate. Revisit when Compose and Testcontainers work against it.

### The substrate, and how it refines ADR-010

ADR-010 says the repository does not maintain or deploy a shared container stack,
and that services belong to the projects that own them. That still holds. But
performance work on a VM-backed runtime lands on four objects that are shared by
construction, and leaving them undeclared meant they were rebuilt by hand from a
document:

- **the VM** — sized deliberately; the only always-on cost
- **one Docker network** with a pinned subnet, so a future host route covers every
  cluster and the bridge address does not move
- **a shared image registry**, because every k3d node has its own containerd image
  store and a second cluster otherwise re-pulls everything the first already had
- **a persistent BuildKit builder**, because image build is the operation run most
  often and the one where a VM-backed runtime is weakest

`script/container-substrate` owns those, idempotently, with `--dry-run`, `--status`
and a `--verify` that exits non-zero.

The line this draws is **state**: the repository may own substrate that holds no
application state — a network, an image cache, a build cache, all rebuildable from
nothing — and still must not own services with data. A database, a queue, an
observability stack remain project-local. Nothing in `container-substrate` creates
one, and the distinction is what keeps ADR-010 intact rather than quietly widened.

Clusters stay out. A `k3d.yaml` belongs in the project repository so its shape is
version-controlled rather than tribal knowledge, and because cluster CIDRs and
ingress ports are project decisions.

### Everything the substrate publishes binds to loopback

A Docker port mapping without a host part binds `0.0.0.0`. `--port 5000` therefore
publishes an unauthenticated image registry to every network the laptop joins, and
`80:80` does the same for a cluster's ingress.

The repository already required container ports to bind `127.0.0.1`, and this is
the class of thing that invariant exists for: it is a laptop, it joins untrusted
networks, and the repository installs an outbound firewall precisely because of
that. So the registry is created as `--port 127.0.0.1:5000`, `--verify` fails when
an existing registry is published more widely, and the documentation gives cluster
port mappings the same treatment.

The same reasoning excludes the wildcard-DNS convenience. It is a genuine
quality-of-life win — hostnames instead of ports — but it needs dnsmasq running as
a privileged service, and dnsmasq listens on all interfaces unless told otherwise.
`AGENTS.md` forbids automatic network-service enablement and `bootstrap` states that
no network service is enabled by this repository. It stays out; an operator who
wants it should add `listen-address=127.0.0.1` and `bind-interfaces`, and know they
have taken on a listening daemon.

### Rosetta is opt-in

`--vz-rosetta` makes amd64-only images usable, and is free if never exercised. It
also requires Rosetta to be installed, and `AGENTS.md` forbids installing it
automatically. So `SUBSTRATE_VM_ROSETTA` defaults to false and warns when enabled.

### Colima settings that cannot be changed in place are verified by read-back

`--mount-type=virtiofs` is discarded on a profile created with anything else.
Colima emits one line —

    level=warning msg="'volume mount type' cannot be updated after initial setup, discarded"

— and then starts on the old value. Observed on the first real run here: the
repository declared virtiofs and the guest mounted `fuse.sshfs`, which is the slower
path and the one the tuning exists to avoid.

This is ADR-016's failure mode in a new place: a setting that is accepted, stored and
ignored, where the only symptom is that everything is quietly slower.
`container-substrate` therefore reads the mount type back out of the profile Colima
wrote, reports it in `--status` and fails `--verify` on a mismatch, rather than
trusting that passing the flag did anything.

Fixing it requires `colima delete`, which destroys the profile's contents. That is
affordable only because everything the repository puts in there is declared: the
network, the registry and the build cache are all rebuilt by the next apply, and
images are re-pullable by definition. A substrate holding application state could not
be treated this way, which is the same reason ADR-010's boundary is drawn at state.

### colima.yaml is deliberately not chezmoi-managed

`colima start` rewrites `~/.colima/default/colima.yaml`, because `--save-config`
defaults to true. Putting that file under chezmoi would recreate, exactly, the
Rancher `rcfiles` problem this decision exists to escape: a tool and a
configuration manager both claiming one file, with an overwrite prompt on every
apply. Settings are passed as flags, and `--save-config` then persists them so a
later bare `colima start` reuses them.

Sizing is verified rather than assumed. An existing profile keeps the sizing it was
created with: CPU and memory take effect on the next start, but a disk can only
grow. So `container-substrate` compares the declared sizing against
`colima list --json` and reports drift instead of starting an under-provisioned VM,
which would otherwise run — and simply be mysteriously slow.

### k3d and kind together, under ADR-022

ADR-022 allows one tool per job in the default profile, and two local-cluster tools
would normally be drift. This overlap is deliberate, and both live in the opt-in
`kubernetes` profile rather than the default:

- **k3d** runs k3s, which is what a single-machine cluster should be: Traefik,
  ServiceLB and metrics-server included, seconds to create and destroy. The daily
  driver.
- **kind** runs upstream Kubernetes, which is what a managed cloud cluster is. The
  parity tool when a project targets EKS, GKE or AKS.

Choosing by production target is the reason to keep both. Neither substitutes for
the other, and collapsing to one would silently cost whichever parity mattered.

### The package count rose while the installed surface fell

Replacing one cask with four formulae — colima, docker, docker-compose,
docker-buildx — raised the default selection from 48 entries to 51, so ADR-013's
ceiling moved from 50 to 55.

Worth recording because the number moved opposite to the thing it proxies for. What
is actually installed went down: no Electron application, no bundled Kubernetes
control plane, no privileged daemon, no GUI updater. A cask that installs a whole
desktop runtime counts as one entry; so does a single-purpose CLI binary. The
ceiling remains useful as a brake on casual additions and cannot be read as a
security metric by itself.

### Applying the substrate is not part of `chezmoi apply`

Hook 25 does not start the VM. Creating it downloads a guest image, takes minutes,
and commits 14 GiB of standing memory — and the VM never returns memory to macOS.
That belongs to a decision the operator makes, not to a side effect of applying
dotfiles, which is the same reasoning that keeps FileVault, Touch ID for sudo, the
macOS defaults and the MCP policy opt-in. The hook reports substrate state and names
the command that changes it.

## ADR-038: Kubernetes belongs in the default profile

**Status:** accepted. Amends ADR-013.

ADR-013 keeps the default selection small and makes specialist capabilities opt-in,
and it names Kubernetes among the specialists. The principle stands. The
classification was wrong for this machine.

This workstation exists for Docker, Kubernetes and AI development. A default
installation that cannot do Kubernetes is not a smaller default — it is an incomplete
one, and it pushes the operator into `--profiles` gymnastics for the thing the machine
was bought to do. "Specialist" should mean *not everyone needs this*, not *the owner
needs this on day one*.

So `kubernetes` joins `core,dev,security,productivity,backup`.

### What it costs, stated plainly

The default trusted computing base grows from 51 entries to 64: kubectl, helm, k3d,
kind, k9s, kubectx, stern, kubeconform, krew, argocd, kustomize, helmfile and
kubeseal. `tests/render-brewfile.sh` raises its ceiling from 55 to 70 to match, which
is a reviewed decision rather than drift — the point of that ceiling is to make growth
deliberate, and this is it being deliberate.

Every one of those is a single static binary. None installs a daemon, a system
extension, a login item or a GUI updater, and none holds credentials of its own. That
is why 13 additions are acceptable here where 13 casks would not be: ADR-013's real
concern is "unrelated credentials, background components, permissions and update
surfaces", and a CLI that reads a kubeconfig introduces none of those.

### What did NOT change

- ADR-013 itself. Cloud provider CLIs, data clients, privileged security monitors and
  personal productivity applications remain opt-in, for exactly the reasons it gives.
- ADR-022's one-tool-per-job rule. k3d and kind still both ship, still for the reason
  ADR-037 records: k3d runs k3s for single-machine parity, kind runs upstream
  Kubernetes for managed-cloud parity, and the production target decides which.
- The container runtime is still a mutually exclusive choice, and Kubernetes still
  needs one. Selecting `kubernetes` with `--runtime none` installs the clients and
  gives them nothing to talk to, which is a legitimate combination for working
  against remote clusters and a useless one for local development.

### Verification consequence

`script/test-install` defaults to the full set, so `k3d` is now present in the guest
and the Kubernetes half of the workstation is exercised by every destructive run
rather than needing a hand-written `--profiles` argument. That was the immediate
prompt for this decision: the first substrate verification reported `k3d absent`,
which was correct and also a sign the default did not match the machine's purpose.

## ADR-039: Registry credentials go to the Keychain; Git LFS is not optional

**Status:** accepted

Two gaps found by reviewing the provisioned workstation against what it is for.

### Registry credentials were stored in the clear

With no credential helper configured, `docker login` writes

    {"auths":{"ghcr.io":{"auth":"<base64 of user:token>"}}}

into `~/.docker/config.json`. Base64 is encoding, not encryption, so a registry token
was readable by anything that could read the file — on a machine whose purpose is
pulling and pushing images, in a repository whose SECURITY.md says no secrets belong
in plaintext. Anonymous pulls were unaffected, which is why nothing surfaced it.

`docker-credential-helper` provides `docker-credential-osxkeychain`, and it is declared
in `profiles/runtime-colima.Brewfile` rather than `core` because it is only useful
alongside the Docker CLI that fragment owns.

### The config file is modified, not owned

`~/.docker/config.json` is managed with chezmoi's `modify_` mechanism, which receives
the current content on stdin and writes the new content out. It is not a managed file,
deliberately: Docker writes to it itself — `auths` on login, `currentContext` on
context switch — so a fully managed file would be reported as modified outside
chezmoi's control on every apply, with a prompt to overwrite that would discard what
Docker had just stored. That is the Rancher Desktop `rcfiles` fight ADR-037 exists to
escape, and choosing it here would have been self-inflicted.

The script passes content through unchanged, with a warning, when `jq` is missing or
the existing file is not valid JSON. Silently skipping a security control is worse
than failing to apply it, and truncating a file that may hold credentials is worse
than both.

### Attribute order is load-bearing, and chezmoi does not enforce it

The entry was first written `private_modify_config.json.tmpl`. chezmoi consumed
`private_` and treated `modify_` as part of the filename, then created a literal
`~/.docker/modify_config.json` containing 3304 bytes of the script's own source. No
error, no warning; the credential store was simply never configured. `modify_` must
come before `private_`.

`tests/chezmoi-templates.sh` now fails when any managed target's name still begins
with a chezmoi attribute prefix, which is the general form of that mistake. The
existing dotfile check could not catch it, because the stray file sat inside `.docker`
rather than at the top of the home directory.

### Git LFS

`git-lfs` was commented out with the note "only needed when a repository actually uses
LFS". Model repositories do — Hugging Face stores weights in LFS — and this
workstation exists partly for AI development. Cloning one without it silently yields
pointer files instead of weights, which presents as a corrupt model rather than a
missing tool.

Installing the package is half the fix. The clean, smudge and process filters must be
in Git's configuration too, and they are declared in `chezmoi/dot_gitconfig.tmpl`
rather than left to a `git lfs install` run-once hook, because chezmoi owns that file
and a hook writing to it would be the same fight as above. `required = true` is
included on purpose: it turns a missing binary into an error instead of a silent
pass-through.

### Not fixed here

Two related observations were left as decisions rather than folded into this one:

- Image scanning and Dockerfile linting — `trivy`, `hadolint`, `dive`, `syft`,
  `grype` — remain in the opt-in `security-scan` profile, although containers are now
  the default purpose. That is the same misclassification ADR-038 corrected for
  Kubernetes and probably wants the same treatment.
- `~/.kube` is unmanaged, so `~/.kube/config` gets whatever `kubectl` or `k3d`
  creates. The repository manages `private_dot_ssh` at 0600 and `private_dot_gnupg` at
  0700 precisely because they hold secrets, and a kubeconfig holds cluster tokens and
  client certificates.

## ADR-040: Dockerfile linting and image scanning are default tools

**Status:** accepted. Amends ADR-015.

`trivy` and `hadolint` move from the opt-in `security-scan` profile into `dev`.

This is the same correction ADR-038 made for Kubernetes. ADR-015 classified every
single-binary scanner as an interactive, occasional activity — reasonable when
containers were one execution domain among four. Containers and Kubernetes are now the
default purpose (ADR-037, ADR-038), which makes linting a Dockerfile and scanning an
image part of authoring rather than a specialist excursion. A default that can build
images but not check them is not a leaner default; it is one that ships the risk and
withholds the tool.

They land in `dev` rather than in a scanner profile because what they validate is this
repository's own output, which is what `dev` already carries: shellcheck for shell,
yamllint for YAML, actionlint for workflows, hadolint for Dockerfiles, trivy for the
images and manifests those produce.

### Only two moved, and ADR-022 is why

The remaining five stay opt-in because each overlaps something already installed or is
not a daily tool:

| Tool | Why it stays opt-in |
|---|---|
| `grype` | Matches images against vulnerability data — trivy already does that |
| `osv-scanner` | Lockfile vulnerabilities — inside trivy's dependency scanning |
| `trufflehog` | Credential scanning — `gitleaks` is already in `core` and is what `./script/test` runs |
| `syft` | SBOM generation is a release and compliance step, and grype's input |
| `dive` | Image layer inspection is for debugging a build, not for every build |

ADR-022 permits one tool per job in the default profile, and moving all seven would
have put two vulnerability scanners and two secret scanners on every machine. The
question each had to answer was not "is this good" but "does the default already have
something for this job".

`tests/render-brewfile.sh` asserts trivy and hadolint are present AND that the other
five are absent, so a later addition has to argue rather than drift in.

### Cost

The default grows from 66 entries to 68. Both are single static binaries with no
daemon, no persistent state and no privileged access — the class ADR-015 already
established as acceptable on the host. What changed is only whether they are opt-in.

### Deliberately not addressed

`~/.kube` remains unmanaged. It holds cluster tokens and client certificates, and the
repository manages `private_dot_ssh` at 0600 and `private_dot_gnupg` at 0700 for
exactly that reason, so the inconsistency is real and recorded — but it was reviewed
and left alone rather than overlooked.

## ADR-041: The declared macOS defaults and the application firewall are on by default

**Status:** accepted. Amends ADR-012.

`./bootstrap install` now applies the `script/macos-defaults` table and enables the
application firewall with stealth mode. `--no-macos-defaults` and `--no-hardening`
decline them; `--with-macos-defaults` and `--with-hardening` remain accepted and are
redundant.

ADR-012 kept hazardous and stateful capabilities out of the baseline, and that rule
still holds — what changed is the finding that these two were never in that category.
The test that established it is recorded in the evidence directory: both were applied to
a guest, `macos-defaults --verify` read every declared key back in effect,
`hardening-check` moved firewall and stealth from `[FAIL]` to `[PASS]` and dropped the
failure count from eight to two, and SSH survived the firewall coming up mid-bootstrap
because `--getallowsigned` auto-permits Apple-signed software and `sshd` qualifies.

Both are reversible, which is the property ADR-012 actually cares about.
`macos-defaults` records every previous value to a `macos-defaults-before.*` transcript
before writing, and the firewall is two `socketfilterfw` calls. FileVault, Rosetta,
Touch ID PAM and major OS upgrades stay opt-in precisely because they are not: each is
either irreversible or can reboot.

The argument for flipping them is that opt-in made the safer state the one you had to
remember. A workstation whose purpose includes handling credentials shipped with its
firewall off and every declared default unset whenever a flag was forgotten, and nothing
reported it — `hardening-check` is non-strict by default, so it warned and continued.
The failure mode was silent, and a declarative configuration that does not apply what it
declares is not conservative, it is inaccurate.

### What this costs

Stealth mode stops the machine answering `ping`, so a host that has gone quiet on the
network is now the expected result rather than a symptom. `docs/TESTING.md` says to use
SSH rather than ICMP to decide whether a guest is alive, and recommends `--no-hardening`
for a machine reachable only remotely.

`script/test-install` defaults to true as well. A harness whose defaults differ from the
defaults it tests exercises a configuration nobody ships, which is how these two paths
stayed unproven through every earlier run. It also forwards the negative explicitly:
once a missing flag means "on", passing nothing for `--no-hardening` would have produced
a hardened guest from a run that asked for the opposite.

## ADR-042: mise owns the JVM ecosystem; SDKMAN is declined

**Status:** accepted. Amends ADR-021.

`java`, `maven`, `gradle` and `kotlin` are declared in
`chezmoi/dot_config/mise/config.toml.tmpl` alongside node, go, pnpm, python and rust.
Two JDKs are pinned — `temurin-21` first and therefore default, `temurin-17` because
Couchbase SDK and connector work still spans it. `tests/render-brewfile.sh` refutes
Homebrew-installed `maven`, `gradle`, `kotlin`, `openjdk` and `sdkman-cli`.

SDKMAN was the preferred tool and was declined on three specific grounds, not on taste.

**It cannot be installed within this repository's existing rules.** Neither `sdkman-cli`
nor `sdkman` exists in homebrew-core, checked against the formulae API. That leaves a
third-party tap — the route ADR-020 rejected for AeroSpace and tflint, and which Homebrew 6
now gates behind per-item `brew trust` — or `curl … | bash`, which ADR-006 and `AGENTS.md`
forbid as unreviewed remote-script execution. Adopting it therefore required suspending one
of two standing decisions, for a capability already available.

**Its installer writes to a file chezmoi owns.** SDKMAN appends `sdkman-init.sh` sourcing to
`~/.zshrc`. A tool that rewrites the shell configuration this repository manages is the
precise conflict that made Rancher Desktop expensive enough to drop in ADR-037, and it would
recur on every apply.

**mise already covers the ground.** Verified against its version index: `java` 26.0.2,
`maven` 3.9.16, `gradle` 9.7.0, `sbt` 2.0.6, `scala` 3.8.4, `kotlin` 2.4.10, `jbang` 0.141.0.
Per-project selection works the way SDKMAN users expect — `mise use java@temurin-17` writes
the project's own pin — so nothing about the workflow is lost.

### Why this is an amendment rather than a new rule

ADR-021 already says one manager decides each version, and that a second installer is a
second place the version is decided. The JVM was the one ecosystem where that rule had gone
unstated, because only the JDK was declared and the build tools were absent entirely — so
`mvn` and `gradle` were, in practice, whatever a project happened to find. Declaring them
here closes that gap rather than opening a new question.

`sbt` and `scala` are deliberately not declared yet. They are available from the same
manager and should be added when Scala SDK or Spark connector work actually starts, rather
than installed against the possibility.

## ADR-043: Containerised agent tools are a declared category

**Status:** accepted. Refines ADR-010 and ADR-037.

ADR-037 drew a line and named it precisely: the repository may own container
**substrate** that holds no application state — a network, an image cache, a build
cache, all rebuildable from nothing — and must not own **services with data**, which
stay project-local under ADR-010.

OpenHands fits neither side. It is not a project's service: no project owns it, and
its lifecycle is the workstation's rather than any repository's. It is not substrate
either: it keeps conversations, settings and provider credentials in `~/.openhands`.
Left unclassified it would have gone into `script/container-substrate`, where ADR-037
explicitly forbids it, or into a project that does not exist.

So there is a third category, deliberately narrow: **a workstation tool that ships as
a container**. `agent-tools/*.lock` pins them and `script/ai-agent` runs them.

### The four conditions

A tool may enter this category only with all four, and `tests/agent-tools.sh` enforces
each one rather than trusting the launcher to keep getting it right:

1. **Pinned by digest.** The lock file carries `image`, `version` and `digest`, and the
   launcher runs `image@digest`. `version` is for humans and for
   `script/update-report`; the digest is what executes. This is ADR-006's objection to
   mutable tags applied where it started.
2. **Loopback only.** Every published port binds `127.0.0.1`. Upstream's quickstart
   uses `-p 8000:8000`, which binds `0.0.0.0` — on a laptop that joins untrusted
   networks that publishes an agent with filesystem write access to everyone on the
   network. The image also exposes 8002 for noVNC; it is deliberately not published.
3. **No Docker socket.** OpenHands has a backend mode that runs agents in containers of
   its own, and enabling it means mounting `/var/run/docker.sock`. That is the
   general-purpose socket mount the security invariants refuse, and the refusal costs a
   feature — which is the point at which an invariant is worth something.
4. **One state directory and one project mount.** `~/.openhands` and one projects root
   from `OPENHANDS_PROJECTS_PATH`. Nothing else: not the home directory, not `~/.ssh`,
   not a kubeconfig. The test counts the mounts, because "one more mount" is how this
   erodes.

### Why the directory is not called `containers/`

`tests/placement-policy.sh` has always asserted that no top-level `containers/`
directory exists, and that the managed-home equivalent does not either. That name is
where a shared workstation compose stack would live, which is exactly what ADR-010
refuses. A lock file is not a stack, so an exception could have been argued — but the
guard's value is that it is unarguable, and it is worth more intact than reinterpreted.
The category took `agent-tools/` instead. One lock per tool, as in `mcp/toolhive.lock`
and `vm/tart.lock`.

### What the boundary costs, stated rather than discovered

The agent runs with the container's toolchain, not the host's. The image carries Python
and Node; it carries no Go, Java or Rust, so for projects in those languages the agent
can edit files but cannot build or test what it wrote. Nor does it reach the host's Git
identity, credentials or signing key — commits it makes are unsigned and carry a
container-local identity, so review and push happen on the host.

Both are consequences of the isolation being real. They are recorded here because
discovering them mid-task reads as breakage rather than as design.

## ADR-044: aider comes from uv and Cline from npm; neither comes from Homebrew

**Status:** accepted. Extends the AI carve-out in ADR-022.

Homebrew is this repository's host package manager and the first thing to try. For
these two it is the wrong answer, for different reasons, and both are worth recording
because the obvious `brew "aider"` / `brew "cline"` will look correct to the next
reader.

### Cline: the formula is deprecated, and npm is the live channel

`brew "cline"` exists. homebrew-core has **deprecated** it — "uses non-FOSS
`@anthropic-ai/claude-agent-sdk` and pre-built binaries" — and `script/check-tokens`
fails on any deprecated token, so declaring it would turn the scheduled
`.github/workflows/tokens.yml` run red. It is also stale: 3.0.3 against npm's 3.0.55.
And it `depends_on node`, which would put a Homebrew Node beside mise's and give the
toolchain version two places to be decided, the precise objection in ADR-021.

The CLI is declared as `"npm:cline"` in `chezmoi/dot_config/mise/config.toml.tmpl`,
beside the `node` pin that satisfies it. Upstream says `npm i -g cline`; that would
install under whichever Node prefix mise currently owns, vanish at the next `node`
bump, run every lifecycle script in the tree, and leave the version undeclared. mise's
`npm:` backend keeps the pin in the file that already decides the Node version, orders
`node` ahead of `npm:` tools, and installs through an embedded package manager that
denies dependency lifecycle scripts by default.

The prebuilt binary is real and is not glossed over: `cline` resolves a Bun-embedded
executable from a per-platform optional dependency. What makes it acceptable here is
the evidence npm carries with it — an integrity hash, a registry signature and an SLSA
v1 provenance attestation — which is a better record than the deprecated formula
offered, and the same shape of trust already accepted for tart and ToolHive.

No `allow_builds` is needed, and adding one would be a mistake. The package's
`postinstall.mjs` only hard-links that binary to `bin/.cline` as a startup
optimisation, and `bin/cline` walks `node_modules` for it at runtime when the link is
absent. Denying the script costs launch latency, not function.

`@cline/llms` depends on `ollama-ai-provider-v2`. That is an API **client**, not the
Ollama runtime, so ADR-025 holds. It is stated because `profiles/AGENTS.md` warns that
the placement test matches literal tokens and cannot see a bundled engine — this is the
case that warning is about, so the reading is recorded rather than the check trusted.

Licensing is mixed and worth naming: `cline`, `@cline/sdk`, `@cline/agents` and
`@cline/cli` are Apache-2.0; `@cline/llms` and `@cline/core` publish no licence field.

The IDE half is unrelated to any of this and takes the channel it always would:
`saoudrizwan.claude-dev` pinned in `vscode/extensions.list` under ADR-032.

### aider: Homebrew builds what PyPI ships prebuilt, and the interpreter clashes

`brew "aider"` is current and not deprecated, so it was a real candidate. Two things
decided against it.

**The interpreter.** `aider-chat` requires Python `<3.13,>=3.10`. mise pins
`python = "3.13"`, so mise's interpreter cannot host it. Adding a second mise Python
would put a version of the wrong kind of thing into the file that declares runtimes.
`uv tool install --python 3.12` fetches a standalone CPython 3.12 into
`~/.local/share/uv/python/` and uses it for that one venv: it never becomes `python3`
on `PATH` and never competes with mise's 3.13.

**The build.** Homebrew compiles numpy and scipy from source, so the formula pulls
`gcc`, `openblas`, `freetype`, `jpeg-turbo` and a `python@3.12` keg — the heaviest
dependency graph in the `dev` profile. PyPI publishes arm64 wheels for all of them, so
uv installs the same software with no compiler involved. The lighter option is also the
one that keeps Homebrew free of a language runtime.

This is not a new channel. `docs/OPERATIONS.md` already answers "a Python CLI with no
Homebrew formula" with `uv tool install`, for `huggingface_hub[cli]` and `crawl4ai`.
What is new is that aider is a default part of `dev` rather than something typed by
hand when wanted, so `run_onchange_after_29_uv-tools.sh.tmpl` installs it at the pinned
version on a new machine.

### Neither is a second tool for a job already covered

ADR-022's carve-out says AI coding agents are not one job, because each reaches a
different provider and the plurality is the reason for having them. That still holds
and now covers five: `codex`, `claude-code`, `opencode`, `cline` and `aider`. aider is
the one that needs a distinct justification, since `opencode` is also
provider-agnostic — it earns its place on a different working model, a git-native
edit-and-commit loop over a repository map, rather than on a different backend.

## ADR-045: CI's own toolchain is pinned, and installed without a curl-pipe

**Status:** accepted. Applies ADR-006 to the place it was missing.

`.github/workflows/validate.yml` installed the four tools that decide whether a
change may merge like this:

```yaml
go install mvdan.cc/sh/v3/cmd/shfmt@latest
go install github.com/rhysd/actionlint/cmd/actionlint@latest
go install github.com/zricethezav/gitleaks/v8@latest
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
```

Both halves contradicted rules this repository enforces elsewhere:

- **`@latest`.** `tests/mcp-policy.sh` fails any MCP package spec that floats,
  and ADR-029 requires an explicit version on every one. The linters that gate
  every merge floated anyway.
- **The curl-pipe.** AGENTS.md forbids unreviewed remote-script execution beyond
  the documented Homebrew bootstrap, and ADR-042 gave *exactly this* as a reason
  to reject SDKMAN — "curl-pipe-bash, which ADR-006 and AGENTS.md forbid". A tool
  was declined for the thing CI did on every run.

That is the part worth recording: the rule was not merely unapplied here, it was
applied hard enough elsewhere to reject a tool. An invariant enforced against
third-party packages and waived for one's own build system is not an invariant.

### What replaces it

Four pinned `go install` lines, chezmoi included. Three consequences:

- **The curl-pipe is gone rather than pinned.** chezmoi is written in Go, so it
  comes from the same mechanism as the other three and the remote-script execution
  disappears entirely. A `go install` build cannot self-upgrade and reports its
  version as `dev`; nothing in this repository parses either, and the subcommands
  the tests use are all present.
- **Pinning brings integrity, not just reproducibility.** `go install` verifies
  the module against the Go checksum database, so a pinned version is a verified
  one. That is a stronger guarantee than the release tarball downloads elsewhere in
  this repository get, and it costs nothing.
- **gitleaks moves to `github.com/gitleaks/gitleaks/v8`**, its canonical path. The
  old `zricethezav` path serves the identical commit, but only through a GitHub
  redirect, and `vm/tart.lock` already argues against letting review depend on a
  redirect that upstream can retire.

`tests/placement-policy.sh` asserts both rules against the workflows, checking the
code rather than the comments — the workflow now explains both rules in prose, and
a check that matched the explanation would teach the next author to delete it.

The `macos-render` job's `brew install` is deliberately left alone: Homebrew has no
version pinning, and using it is how everything else on the host arrives. Runner
images stay on `ubuntu-latest` and `macos-latest`, where pinning would trade a
supply-chain gain for silent bit-rot.

## ADR-046: Telemetry is opted out of, everywhere it can be

**Status:** accepted

This workstation handles credentials, client work and security tooling. What it
has installed, when, and how often it is used is not information anyone else
needs. Where a tool collects it, this repository turns it off; where it cannot,
the fact is written down rather than left as an assumption.

The rule is not "block network access" — Homebrew still downloads, `trivy` still
fetches its database. It is narrower: **no tool reports our usage of it to its
vendor.**

### What the audit found

Every package in every profile, plus the mise runtimes, the editor extensions,
the MCP servers, the CI toolchain and the containerised agent tools. Three
categories came out of it, and the distinction between them is the useful part.

**On by default — closed:**

| Tool | What it sent | How it is off now |
|---|---|---|
| Homebrew | usage analytics to InfluxDB, 365-day retention | `HOMEBREW_NO_ANALYTICS=1`, both shells |
| Azure CLI | `collect_telemetry` reads with `fallback=True` in `telemetry.py` | `AZURE_CORE_COLLECT_TELEMETRY=false` |
| VS Code | usage and crash reports | `telemetry.telemetryLevel: "off"` — MANUAL |
| Zed | usage metrics and crash reports | `telemetry.diagnostics` + `.metrics` — MANUAL |
| OpenHands | PostHog key baked into the image | its own settings — MANUAL |

Homebrew is the one that mattered most. It runs on every install, update and
upgrade, and what it reports is the list of what this machine has.

**Off, local, or opt-in by default — pinned shut anyway:**

| Tool | Default | Set anyway because |
|---|---|---|
| Go | telemetry is `local`: collected, not uploaded | `go telemetry off` declines collection entirely; hook 31 |
| gcloud | reports only if you opted in at install | an installer question answered once is not a decision anyone remembers; hook 31 |
| aider | analytics are opt-in and it prompts | `--analytics-disable` answers before it asks, inside an interactive session; hook 31 |
| Claude Code | OTel export is opt-in via `CLAUDE_CODE_ENABLE_TELEMETRY` | left unset, which is the off state |

Pinning a default is not redundant. A default is the vendor's choice and can be
changed in a release; a written setting is ours and changes when we change it.

**Checked, nothing found:** `mise`, `uv`, `opencode`, `k9s`, `helm`, `trivy`,
`docker` (the CLI — Docker Desktop is not installed; Colima is the runtime),
`obsidian` (its documentation states plainly: "We do not collect any telemetry
data"), `starship`, `gh`, `chezmoi`, `ghostty`, `restic`, `rclone`, and the rest
of `core`.

That phrasing is deliberate. **Nothing found is not the same as nothing there.**
These were checked against vendor documentation and, where it was quicker to
read than to search, source. A tool that collects quietly and documents nothing
would pass this audit, so the conclusion is "no evidence", not "proven clean".

### Where each opt-out lives, and why

**Environment variables go in both shell configurations.** They apply per
invocation with no state to drift, and there is no file to reconcile.
`tests/placement-policy.sh` compares the two shells as sets: an opt-out present
in zsh and missing from fish would mean the machine's posture depended on which
terminal was opened, which is not a posture.

Only variables whose effect was **verified** are set. A plausible-looking
variable that nothing reads is worse than none — it reads as coverage and
provides none. `DO_NOT_TRACK=1` is the one exception and is labelled as such: it
is an informal convention (consoledonottrack.com), honoured by whichever tools
chose to, set as a blanket signal and never as a substitute for a specific
variable.

**Three settings have no variable** and are written by the tool into its own
config, so `run_onchange_after_31_telemetry-optout.sh.tmpl` runs them once per
machine. Each step is guarded on the tool being present, is a no-op when the
setting is already correct, and never fails the apply — chezmoi stops at the
first failing script, and a telemetry setting must not cost the macOS defaults,
the browser profiles or the security reminder that run after it.

**Two editors are manual, deliberately.** `vscode/README.md` already states that
this repository does not edit `settings.json` — "that file is yours". Setting the
telemetry key would mean owning the file, and the boundary is worth more than the
automation. They are steps 11 in `docs/MANUAL-SECURITY.md`, beside the other
decisions only a human can make.

### What this does not cover

Applications that phone home as part of their function rather than as telemetry:
a browser's safe-browsing lookups, `trivy`'s vulnerability database, Homebrew's
own downloads. Those are the tool working, not the tool reporting, and blocking
them belongs to the outbound firewall (LuLu) as a per-application decision rather
than here.

Nor does it cover a tool that adds telemetry in a later release. Nothing detects
that. `script/update-report` lists what changed before an upgrade, and a new
analytics notice is the kind of thing that appears in release notes — which is an
argument for reading them, not a control.
