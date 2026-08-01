# Security policy

## Supported state

This repository is a personal workstation baseline. Security fixes apply to the
current `main` branch.

## Reporting

Do not open a public issue containing credentials, private hostnames, cloud
account identifiers or vulnerability evidence from customer systems.

Report anything sensitive privately through GitHub's security advisory form for
this repository, which keeps the report out of public view until it is
resolved.

## Bootstrap trust boundary

The bootstrap may install Xcode Command Line Tools, Homebrew, Git, GitHub CLI,
`age`, `git-delta` and chezmoi. Review changes to `bootstrap`,
`script/lib/common.sh` and chezmoi `run_*` scripts with elevated scrutiny.

The Homebrew installer is the only remote script this repository executes. It is
downloaded to a temporary file and its SHA-256 printed for review before it
runs; it is never piped from `curl` into a shell.

`./bootstrap install --with-touchid-sudo` writes `/etc/pam.d/sudo_local`. It is
opt-in, requires confirmation, and uses the file Apple provides for this purpose
so a macOS update cannot silently revert or break it.

## Supply chain

- GitHub Actions are pinned to commit SHAs, not tags, matching the rule this
  repository applies to container images.
- Only `homebrew/core` and `homebrew/cask` are used. Adding a third-party tap
  extends the trusted supply chain and requires its own decision record.
- `./script/check-tokens` verifies every declared Homebrew token still exists
  upstream and is neither deprecated nor disabled. It runs weekly in CI.

## Package and image changes

For every new package or image:

1. justify why it belongs on the host, in a container or in a VM
2. verify the publisher and upstream repository
3. prefer official Homebrew formulae/casks and official images
4. review permissions, system extensions and login items
5. pin container images to immutable digests
6. avoid Docker socket and broad home-directory mounts

## MCP servers

An MCP server is arbitrary code with tool access to the machine, and the usual
invocation pattern executes unpinned remote code at every agent start. Treat one
as you would a package, not as a configuration value:

1. inspect the tools it exposes with `mcp-inspector` before trusting it
2. pin an explicit version; `@latest` is rejected by `tests/mcp-policy.sh`
3. allowlist it by `serverCommand` or `serverUrl` in `mcp/managed-settings.json`
   — never by `serverName`, which any server can claim
4. run it under ToolHive so it holds no host credentials
5. review the Codex and opencode configurations by hand: only Claude Code
   enforces the allowlist

## Secrets

No secrets belong in this repository. Use short-lived cloud sessions, hardware
security keys, password-manager references and SOPS/age-encrypted project files.

## Work that stays manual

`docs/MANUAL-SECURITY.md` lists what this repository deliberately does not do for
you, and why: FileVault and its recovery key, remote services, hardware keys, TCC
permissions, browser sync, Touch ID for sudo, backup restore drills and the
outbound firewall. Each entry says how to verify it rather than only what to do.

## Recorded terminal sessions

`script` captures everything that reaches the terminal, including prompts that
echo. Casks installing a privileged component prompt for an administrator
password through Homebrew rather than through `sudo`, so it is written into the
recording in clear text — observed during a real install of `oversight`.

Run `sudo -v` before starting a recording so the credential is already cached,
and treat any recording made across a privileged install as containing one until
checked with `grep -c "Password:"`. Destroy such a file rather than editing it;
an edited copy leaves the original blocks on disk.
