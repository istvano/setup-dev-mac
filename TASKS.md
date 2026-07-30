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
- [ ] Run `./script/test` on the Mac. It is now verified against bash 3.2.57, the
      version macOS ships, but only Linux CI has run the shellcheck, shfmt,
      actionlint and gitleaks paths on the real binaries.
- [ ] After the first `chezmoi apply`, confirm nothing landed in `$HOME` that is
      not a dotfile: `chezmoi managed --include=files,dirs | grep -v '^\.'` must
      print nothing.
- [ ] With the `dev` profile, confirm `./script/vscode-extensions --verify` passes
      and that `--diff` reports the ten pack children rather than calling them
      undeclared.
- [ ] Set `"extensions.autoUpdate": false` in VS Code settings, or accept that
      the pinned versions will drift and `--verify` will keep reporting it.
- [ ] Add macOS integration tests once first-run behaviour has been observed.

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
