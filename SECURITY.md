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

## Secrets

No secrets belong in this repository. Use short-lived cloud sessions, hardware
security keys, password-manager references and SOPS/age-encrypted project files.
