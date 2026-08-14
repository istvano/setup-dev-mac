# The default container runtime (ADR-037).
#
# Colima is a CLI-managed Linux VM on Apple's Virtualization.framework, exposing
# the standard Docker socket. It replaced Rancher Desktop as the default because
# Rancher's cost was structural rather than incidental: a desktop GUI, a bundled
# Kubernetes control plane that this configuration disabled anyway, an idle-CPU
# issue on Apple Silicon, and a PATH-management strategy that rewrites the very
# shell files chezmoi owns. See ADR-037.
#
# `lima` is not declared here: the colima formula depends on it, so Homebrew
# installs it either way. It is declared in profiles/lab.Brewfile for the separate
# purpose of hand-managed Linux guests (ADR-027).
brew "colima"         # CLI-managed Linux VM providing the Docker API on Virtualization.framework.
brew "docker"         # Docker-compatible client. Colima provides the daemon; this is CLI only.
brew "docker-compose" # Compose plugin for project-defined multi-container stacks.
# Build cache is the operation run most often and the one where a VM-backed runtime
# is weakest, so a persistent builder with cache mounts is worth more than any
# network tuning. script/container-substrate creates the builder.
brew "docker-buildx" # Persistent BuildKit builders and cache mounts.
# Without a credential helper, `docker login` writes {"auths":{"registry":{"auth":
# "<base64 user:token>"}}} into ~/.docker/config.json. Base64 is encoding, not
# encryption, so a registry token ends up readable on disk — on a machine whose whole
# purpose is pulling and pushing images, and in a repository whose SECURITY.md forbids
# exactly that. This provides docker-credential-osxkeychain, which stores the token in
# the macOS Keychain instead; chezmoi's modify_ script for ~/.docker/config.json
# selects it. Declared here rather than in core because it is only useful alongside the
# Docker CLI, which this fragment owns. See ADR-039.
brew "docker-credential-helper" # Stores registry credentials in the macOS Keychain.
