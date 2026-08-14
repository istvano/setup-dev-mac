# Codex repository instructions

## Mission

Maintain a secure, reproducible, container-first Apple Silicon workstation
baseline for an expert software engineer specialising in security and AI.

This repository is infrastructure code. Treat changes as security-sensitive,
operationally consequential and expected to remain understandable years later.

## Current user decisions

These are deliberate defaults, not placeholders:

- Target platform: Apple Silicon macOS ONLY. The target is an M5 Max MacBook Pro
  with 128 GB unified memory and 4 TB storage. It is BUILT AND TESTED on a second
  Apple Silicon machine, an M1 Pro with 32 GB — both `arm64`, so this is a capacity
  and generation difference, not an architecture one. Intel support was removed in
  ADR-036 and `require_supported_mac` now fails on `x86_64`. `/opt/homebrew` is the
  only prefix and `/usr/local` is NOT a fallback — on Apple Silicon it means a
  Rosetta x86_64 Homebrew, so falling back selects translated binaries and reports
  success. Still do not hardcode the path at a call site: use `brew_prefix`, or the
  `brew-prefix` / `brew-shellenv` templates, so the prefix keeps one definition.
- Never write a capability claim that is true of only one of the two machines.
  Nested virtualization is the live example: the M1 Pro cannot do it and the M5 Max
  can, so `nested_virtualization_supported` in `script/lib/common.sh` DETECTS it and
  callers report accordingly. Prefer detection over a remembered answer.
- Repository testing: a local macOS VM, built once from Apple's IPSW and cloned per
  run (ADR-036). `script/vm` owns the VM lifecycle, `script/test-install` runs the
  destructive first-install test, and `tart` is installed from the pinned release
  in `vm/tart.lock` rather than from a Homebrew tap.
- Configuration engine: chezmoi.
- Host package manager: Homebrew Bundle with composable profile fragments.
- Runtime managers: mise for general runtimes including Rust, which it manages
  by driving rustup; uv for Python. Homebrew installs no language runtime.
- Repository scripts and validation do not invoke Ruby. Homebrew Bundle may use
  Homebrew's own bundled Ruby internally.
- Local AI baseline: MLX as a project-local Python dependency. LM Studio is the
  only permitted local inference runtime and is opt-in via `local-llm` (ADR-025).
- VS Code extensions are declared in `vscode/extensions.list` with exact pinned
  versions, roots only; nothing is uninstalled automatically (ADR-032).
- Nerd Fonts come from homebrew/cask, never from the upstream installer script.
- Default interactive shell: zsh. fish is the mutually exclusive alternative,
  selected by `--shell`; it never changes the account login shell (ADR-031).
- Default container runtime: Colima (ADR-037). Rancher Desktop remains selectable;
  OrbStack is the paid alternative. Only one runtime may be active.
- Default free password manager: Bitwarden.
- Default free outbound firewall: LuLu.
- Default package profiles: core, dev, security, minimal productivity, backup and
  kubernetes. Kubernetes is core to this workstation, not specialist (ADR-038).
- Cloud providers, Kubernetes, data clients, privileged security monitors and
  personal productivity applications are explicit opt-ins.
- Optional browsers use isolated `personal` and `work` data roots; additional
  lowercase profile names are created explicitly with `browser-profile`.
- BetterDisplay Free Edition is a hard requirement, not a convenience: the
  monitors are shared with a second Mac and DDC input switching moves them
  between the two machines (ADR-007).
- Stateful services and repeatable scanners belong in containers, and they belong to
  the project that owns them. The repository owns only STATELESS substrate: the
  runtime VM, one shared network, an image cache and a build cache (ADR-037). Never
  add a service with data to `script/container-substrate`.
- Every container port the repository publishes binds `127.0.0.1`. A Docker port
  mapping without a host part binds `0.0.0.0`; on a laptop that joins untrusted
  networks that is a real exposure, not a theoretical one.
- Exploit development, malware analysis, GDB-centric workflows and untrusted
  binaries belong in an isolated Linux VM.

## Non-negotiable architecture

Use the smallest appropriate execution boundary:

1. **macOS host** for GUI applications, Keychain/Touch ID, display management,
   raw host networking, VPN/system extensions, macOS inspection and frequently
   invoked low-latency CLI tools.
2. **Project-local uv environment** for MLX and Apple unified-memory workloads.
3. **Linux containers** for databases, vector stores, queues, observability,
   batch scanners and CI-equivalent services.
4. **Isolated Linux VM** for hostile, kernel-sensitive or architecture-specific
   security work. Provided by the `lab` profile (Lima, UTM); before it existed
   this boundary was documented but not installable (ADR-027).

Do not containerise a tool merely for consistency when doing so removes a
required host capability. Do not install a daemon natively merely because a
Homebrew formula exists.

## Sources of truth

- `profiles/*.Brewfile`: host packages and native GUI applications.
- `mcp/managed-settings.json`: the approved MCP server catalogue.
- `mcp/toolhive.lock`: the pinned ToolHive release and its digests.
- `vm/tart.lock`: the pinned Tart release, its digest and its signing team.
- `chezmoi/`: user configuration and idempotent apply hooks.
- `script/`: orchestration, validation and maintenance commands.
- `script/container-substrate`: the declared container substrate — the Colima VM,
  the shared network, the image registry and the build cache (ADR-037). It creates
  no service with data; that boundary is what keeps ADR-010 intact.
- `docs/ARCHITECTURE.md`: current boundaries and configuration flow.
- `docs/DECISIONS.md`: durable architectural decisions.
- `docs/OPERATIONS.md`: installation, update, verification and recovery runbook.
- `TASKS.md`: unfinished work only.

## Change workflow

Before editing:

1. Read `README.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md` and the
   applicable nested `AGENTS.md` file.
2. Inspect the relevant source-of-truth files before proposing changes.
3. Check `git status`; do not overwrite unrelated user work.
4. For current package names, licences or product behaviour, verify against
   primary vendor documentation when network access is available. State when
   current verification was impossible.

While editing:

- Prefer a small focused patch over a broad rewrite.
- Preserve idempotency.
- Keep implementation logic in small scripts; keep `justfile` recipes as thin
  command aliases.
- Explain each package's purpose and why its execution boundary is correct.
- Keep mutually exclusive alternatives in separate profile fragments.
- One tool per job in the default profile (ADR-022). Before adding one, check
  whether an installed tool already covers the use case.
- Never put credentials, recovery keys, private addresses or machine-specific
  absolute paths in tracked files.
- Do not add automatic major macOS upgrades, automatic FileVault enablement,
  automatic Rosetta installation or automatic network-service enablement.
- Templates must never build repository paths from `.chezmoi.sourceDir`
  directly. `.chezmoiroot` resolves it to `<repo>/chezmoi`; use
  `dir .chezmoi.sourceDir`. `tests/chezmoi-templates.sh` enforces this.
- Do not add unreviewed remote-script execution beyond the documented
  Homebrew bootstrap trust boundary.

After editing:

1. Run `./script/test` for every change, including documentation changes that
   affect instructions or workflows.
2. Run the most specific checks for the changed area.
3. On macOS, run `./script/verify` and `chezmoi diff` when the change affects
   applied state.
4. Report what was tested and what could not be tested.
5. Do not commit, amend, tag, push or create a branch unless the user asks.

## Standard commands

```bash
./bootstrap plan
./script/test
REQUIRE_LINTERS=1 REQUIRE_CHEZMOI=1 ./script/test   # what CI runs; no silent skips
./script/render-brewfile --output /tmp/workstation.Brewfile
./tests/render-brewfile.sh
./script/check-tokens          # needs network; not part of ./script/test
./script/verify
./script/update-report
./script/snapshot
./script/macos-defaults --diff
./script/hardening-check --strict
./script/container-substrate --verify
chezmoi diff
```

Destructive first-install testing, in a disposable local macOS guest:

```bash
./script/install-tart      # pinned release; verifies digest and signing team
./script/vm build          # golden image from Apple's IPSW; interactive, once
./script/vm seal           # refuses an image that is not pristine AND usable
./script/test-install      # reset, install from scratch, verify
./script/vm status
```

Convenience aliases:

```bash
just plan
just test
just verify
just render
```

## Testing expectations

The minimum validation gate is `./script/test`. It covers:

- shell syntax and shellcheck, over every file with a shell shebang
- shfmt formatting, actionlint and gitleaks
- Brewfile rendering and restricted entry syntax
- profile-catalogue consistency across the four places that declare it
- chezmoi template execution, including the macOS-only branches
- YAML syntax
- host/project-boundary placement invariants, including that the Intel removal
  cannot half-revert
- the VM tooling: that the tart pin is complete, that the installer still verifies
  the digest and signing team, and that no script joins arguments with `"$*"`
- rendering idempotency
- Codex instruction and skill structure

`./script/test` SKIPS four checks when their tools are absent — shellcheck,
shfmt/actionlint/gitleaks, chezmoi template execution and YAML — and still prints
"All repository tests passed". Run it with `REQUIRE_LINTERS=1 REQUIRE_CHEZMOI=1`
before believing a green result.

Shell scripts are discovered by shebang via `script/shell-files`, never by
filename extension. Selecting by extension previously skipped every
extensionless script in `script/`, which hid three install-breaking defects.
Do not reintroduce a separate file selector in tests or CI.

When changing Homebrew tokens, render the Brewfile and verify current tokens on
macOS. Project repositories own their own Compose validation. Linux CI is static
validation only and cannot prove macOS application behaviour.

When a change affects installation, run `./script/test-install`. Do not report as
passing what the VM cannot prove: on the M1 Pro build machine nested
virtualization is unavailable so no container runtime runs in the guest (the M5 Max
can, and `nested_virtualization_supported` decides which case applies); Apple's
licence permits two macOS guests per host, so matrices are sequential; and Ghostty
needs Metal, which is unverified there.

## Shell standards

- Bash scripts use `#!/usr/bin/env bash` and `set -Eeuo pipefail`.
- Quote variable expansions unless deliberate word splitting is documented.
- Prefer arrays for command construction.
- Avoid `eval` except for vendor-generated shell initialisation such as
  `brew shellenv`, and explain its use.
- Use `mktemp` plus traps for temporary state.
- Back up user-owned files before replacement.
- Never run the complete bootstrap as root.
- Fail closed on invalid choices and ambiguous security state.
- Keep scripts compatible with the Bash version they declare or explicitly
  require a newer one.

## Package placement rules

A new package requires all of:

- a documented use case
- a placement decision: host, project-local environment, container or VM
- a reason the chosen boundary is correct
- a profile assignment
- conflict analysis with existing tools
- licensing classification: free, paid or conditional commercial use
- validation updates where the decision is architectural

Use the `$add-workstation-tool` skill for this workflow.

## Security invariants

Do not weaken these without explicit user approval and a documented decision:

- Container ports bind to `127.0.0.1` by default.
- MCP servers are allowlisted by `serverCommand` or `serverUrl`, never by
  `serverName`, and every package spec carries an explicit version (ADR-029).
- Stateful Linux services use named volumes, not macOS bind mounts for data.
- Scanner source mounts are read-only unless remediation explicitly requires
  writes.
- No general-purpose container mounts `/var/run/docker.sock`.
- No container receives the complete home directory, SSH directory, password
  manager socket, kubeconfig collection or all cloud credentials.
- Cloud scanners use explicit, short-lived, least-privilege credentials.
- Image source tags are resolved to reviewed immutable digests before use.
- Project-local MLX serving binds to loopback and is not presented as
  production-safe.
- Interactive shells, host firewalls and password managers remain mutually
  exclusive choices.
- The account login shell is not reassigned automatically, and `/etc/shells` is
  not edited.

## Documentation contract

Update documentation in the same patch when behaviour, defaults, commands,
package placement or security assumptions change.

Keep `README.md` as the concise entry point, `docs/ARCHITECTURE.md` as the
current-state design, `docs/DECISIONS.md` as durable rationale and
`docs/OPERATIONS.md` as the operator runbook. Use `TASKS.md` for unfinished work
only, not permanent architecture or recurring procedures.

## Codex-specific guidance

- Root `AGENTS.md` applies to the repository. Nested `AGENTS.md` files add
  narrower constraints for their directory trees.
- Repo-local skills live under `.agents/skills/<skill-name>/SKILL.md`.
- Keep this root file comfortably below Codex's project-document byte limit.
- Use the `$workstation-maintainer` skill for broad repository changes.
- Start Codex directly from the repository root after Codex CLI is installed.
