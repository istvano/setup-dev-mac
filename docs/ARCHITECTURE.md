# Architecture

## Objective

Provide a reproducible Apple Silicon workstation while keeping the macOS host
small, auditable and capable of using hardware and operating-system features
that Linux containers cannot provide.

## Execution domains

### macOS host

Owns native GUI, identity, system and high-frequency tooling:

- Homebrew, chezmoi, mise, uv and core CLI
- editors and Codex CLI
- BetterDisplay
- Burp Desktop, Wireshark, Nmap and interactive mitmproxy
- password manager, Yubico Authenticator, Tailscale and outbound firewall
- cloud/Kubernetes control-plane CLIs

### Project-local MLX environments

Each project that needs MLX owns it in a uv environment. This boundary preserves
Apple unified-memory and Metal-backed execution while avoiding global Python
dependency sprawl. MLX-LM, notebooks and serving tools are added only where a
project requires them.

### Project containers

Each project owns its Compose files, service versions, scanners, volumes and
lifecycle. This repository provides only the selected Docker-compatible runtime
and does not deploy a shared workstation stack.

### Isolated Linux VM

Owns high-risk or Linux-specific work:

- GDB/GEF/pwndbg
- pwntools and exploit development
- malware analysis
- untrusted binaries
- x86-specific testing

## Configuration flow

```text
bootstrap
  -> installs trust set
  -> writes chezmoi data choices
  -> chezmoi apply
       -> renders Brewfile from profiles
       -> installs host packages
       -> configures runtimes
       -> applies optional conservative defaults
```

## Trust boundaries

- The bootstrap fetches only the official Homebrew installer as its remote
  bootstrap operation.
- Homebrew packages and casks expand the trusted software set and must be
  reviewed as code-execution dependencies.
- Project container images remain untrusted execution dependencies and should
  be pinned and reviewed within the owning project.
- Chezmoi apply scripts can execute commands as the user and therefore require
  review through `chezmoi diff` and repository review.
