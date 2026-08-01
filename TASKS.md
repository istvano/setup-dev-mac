# Backlog

This file contains unfinished work only. Recurring installation, verification
and hardening procedures are documented in `docs/OPERATIONS.md`.

## Requires the target Mac

Linux CI cannot prove any of these. Record the results after the first install.

- [ ] Run `./script/macos-defaults --verify` and record every key this macOS
      version silently ignores. That list is version-specific and cannot be
      predicted; it belongs here once observed.
- [ ] Confirm `brew bundle check` passes for `kubernetes-cli`, the one
      corrected token still enabled. The `mitmproxy` and `wireshark-app`
      corrections are commented out in `profiles/security.Brewfile`; if they are
      re-enabled, verify them too rather than trusting the old token names.
- [ ] Generate the OpenPGP key, publish the public key to the forge, and verify
      signing end to end: `git log --show-signature -1` must report a good
      signature, not merely a successful commit. Back up the secret key and a
      revocation certificate offline.
- [ ] Confirm Rancher Desktop is configured with Moby and Kubernetes disabled.
- [ ] Prove the lab boundary: `limactl start`, then `ansible -i lab, -m ping all`.
      The isolated-VM domain was documented but unimplemented until ADR-027, so
      it has never actually been exercised.
- [ ] If fish is selected, confirm `ghostty +show-config | grep -E
      'shell-integration|^command'` reports `fish` and the `--login` argument.
      Ghostty is the only thing that launches fish, so a rejected `command` line
      would leave zsh running with no error anywhere.
- [ ] With fish selected, compare `PATH` against zsh's. They should differ only
      in ordering. A missing `/etc/paths.d` entry means `--login` is not taking
      effect, which is invisible until a tool installed by a macOS package is
      not found.
- [x] `./script/test` passes on the Mac, all 12 test scripts. The bash 3.2 fix
      holds — `Shell syntax: OK (34 files)`. It took three rounds to get there:
      the `/usr/bin/python3` Command Line Tools stub, then missing PyYAML, then
      `tomllib` (Python 3.11+; CLT ships 3.9). All three are ADR-033. `shasum`
      turns out to be base-system rather than CLT-gated, so
      `tests/idempotency.sh` needed nothing.
- [ ] Run the suite again after Phase 2 with `REQUIRE_LINTERS=1
      REQUIRE_CHEZMOI=1`. Until the `dev` profile lands, YAML and TOML are
      *skipped* and shellcheck, shfmt, actionlint and gitleaks have only ever run
      on Linux — so the Mac has not yet exercised them on the real binaries.
- [ ] After the first `chezmoi apply`, confirm nothing landed in `$HOME` that is
      not a dotfile: `chezmoi managed --include=files,dirs | grep -v '^\.'` must
      print nothing.
- [ ] With the `dev` profile, confirm `./script/vscode-extensions --verify` passes
      and that `--diff` reports the ten pack children rather than calling them
      undeclared.
- [ ] Set `"extensions.autoUpdate": false` in VS Code settings, or accept that
      the pinned versions will drift and `--verify` will keep reporting it.
- [ ] On the first `git mergetool`, confirm the VS Code panes are the way round
      the config assumes. `code --merge` takes path1, path2, base, result, and
      `$LOCAL` is passed first so your side matches git's ours-before-theirs
      ordering — but which pane VS Code labels as which could not be established
      from its source. Swapped panes would resolve conflicts the wrong way while
      looking normal.
- [ ] Add macOS integration tests once first-run behaviour has been observed.

## Intel development machine

The workstation is being built on an Intel macOS 13 VM until the M5 Max arrives
(ADR-034). What that machine can and cannot settle:

- [x] Every script, chezmoi template, both shell configurations and the whole
      test suite run on Intel. `require_supported_mac` accepts x86_64 with a
      warning, and the Homebrew prefix is discovered rather than assumed.
- [x] First install attempt: 70 of 108 failed on one root-owned
      `/usr/local/share/man/man8`. Homebrew checks prefix writability before
      installing, so one directory fails everything. `require_writable_homebrew`
      now catches it in bootstrap and in the apply hook (ADR-034). Fix with
      `sudo chown -R "$(id -un)" /usr/local/share/man/man8`, then
      `./script/setup`.
- [x] Second install: 195 packages (161 formulae, 34 casks). Nine formulae have
      no macOS 13 x86_64 bottle and their source builds fail — `eza`, `yq`,
      `opencode`, `shellcheck`, `actionlint`, `hadolint`, `pandoc`,
      `mcp-inspector`, `argocd`. An OS-version ceiling, not a repository fault;
      re-check them on the M5. `shellcheck` and `actionlint` missing means
      `REQUIRE_LINTERS=1` cannot fully pass on this VM.
- [ ] Re-apply after ADR-035 and confirm hooks 30/35/40/45/90 now run: VS Code
      extensions installed, browser profile roots created, security reminder
      printed. They were all skipped when hook 25 aborted the apply.
- [ ] Install with all profiles EXCEPT `local-llm`: `lm-studio` declares
      `arch: arm64` and is the only one of 35 casks that cannot install on
      Intel. The other 34 have no arch or macOS constraint that macOS 13 fails.
- [ ] Re-verify the cask set on the M5 Max. Intel proves the tokens resolve and
      the fragments compose; it does not prove an arm64 build of each exists.
- [ ] Confirm the Ghostty `command` line renders to `/opt/homebrew/bin/fish` on
      the M5 Max and `/usr/local/bin/fish` on the VM. It is the one place the
      prefix is baked in at apply time rather than discovered at runtime.

## MCP follow-up

The approved catalogue and container isolation are in place (ADR-029). What
remains cannot be settled from documentation alone.

- [ ] Confirm whether Codex and opencode expose any allowlist or policy
      mechanism for MCP servers. Neither could be verified from their published
      documentation, so both are currently reviewed by hand rather than
      enforced. If a mechanism exists, extend `script/mcp-policy` to it.
- [ ] Install and prove the policy on the Mac: `./script/mcp-policy apply`, then
      `claude mcp add --transport http test https://example.com/mcp` must be
      refused by enterprise policy.
- [ ] Run the first server under ToolHive and confirm it holds no host
      credentials.

## Workstation follow-up

- [ ] Initialise the restic repository and run a restore drill. `backup` is now
      part of the default selection, so the tooling installs; the repository
      itself still does not exist.
- [ ] Enable FileVault and store the recovery key offline.
- [ ] Configure encrypted Time Machine alongside the restic repository.
- [ ] Configure `granted` for the accounts in use before running cloud scans.
