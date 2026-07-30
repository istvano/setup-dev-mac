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
renamed it to `scrollback-limit-bytes` precisely because the units were
ambiguous. Set to `10000` as though it were a line count, it produced a 10 KB
scrollback buffer against a 50 MB default — wrong by more than three orders of
magnitude, while reading as entirely plausible. The comment justifying it was
also wrong: it claimed the limit kept history off disk, but Ghostty never writes
scrollback to disk. The config now uses `scrollback-limit-lines`, and
`tests/placement-policy.sh` rejects the deprecated bare key.

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

`command = /opt/homebrew/bin/fish --login` needs `--login`. fish applies
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
