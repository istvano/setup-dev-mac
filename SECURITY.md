# Security policy

## Supported state

This repository is a personal workstation baseline. Security fixes apply to the
current `main` branch.

## Reporting

Do not open a public issue containing credentials, private hostnames, cloud
account identifiers or vulnerability evidence from customer systems.

## Bootstrap trust boundary

The bootstrap may install Xcode Command Line Tools, Homebrew, Git, GitHub CLI,
`age` and chezmoi. Review changes to `bootstrap`, `script/lib/common.sh` and
chezmoi `run_*` scripts with elevated scrutiny.

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
