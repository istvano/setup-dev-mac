# Codex repository instructions

## Mission

Maintain a secure, reproducible, container-first Apple Silicon workstation
baseline for an expert software engineer specialising in security and AI.

This repository is infrastructure code. Treat changes as security-sensitive,
operationally consequential and expected to remain understandable years later.

## Current user decisions

These are deliberate defaults, not placeholders:

- Target platform: Apple Silicon macOS, currently an M5 Max MacBook Pro with
  128 GB unified memory and 4 TB storage.
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
- Default free container runtime: Rancher Desktop configured with Moby.
- Default free password manager: Bitwarden.
- Default free outbound firewall: LuLu.
- Default package profiles: core, dev, security, minimal productivity and backup.
- Cloud providers, Kubernetes, data clients, privileged security monitors and
  personal productivity applications are explicit opt-ins.
- Optional browsers use isolated `personal` and `work` data roots; additional
  lowercase profile names are created explicitly with `browser-profile`.
- BetterDisplay Free Edition is a hard requirement, not a convenience: the
  monitors are shared with a second Mac and DDC input switching moves them
  between the two machines (ADR-007).
- Stateful services and repeatable scanners belong in containers.
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
- `chezmoi/`: user configuration and idempotent apply hooks.
- `script/`: orchestration, validation and maintenance commands.
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
./script/render-brewfile --output /tmp/workstation.Brewfile
./tests/render-brewfile.sh
./script/check-tokens          # needs network; not part of ./script/test
./script/verify
./script/update-report
./script/snapshot
./script/macos-defaults --diff
./script/hardening-check --strict
chezmoi diff
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
- host/project-boundary placement invariants
- rendering idempotency
- Codex instruction and skill structure

Shell scripts are discovered by shebang via `script/shell-files`, never by
filename extension. Selecting by extension previously skipped every
extensionless script in `script/`, which hid three install-breaking defects.
Do not reintroduce a separate file selector in tests or CI.

When changing Homebrew tokens, render the Brewfile and verify current tokens on
macOS. Project repositories own their own Compose validation. Linux CI is static
validation only and cannot prove macOS application behaviour.

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
