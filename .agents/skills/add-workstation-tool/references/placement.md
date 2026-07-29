# Placement decision matrix

## macOS host

Choose when the tool requires:

- native GUI or browser integration
- Keychain, Touch ID or hardware-key integration
- display APIs, DDC, Accessibility or Screen Recording
- raw host interfaces, packet capture, VPN or system extension
- macOS persistence/process inspection
- very frequent low-latency host filesystem execution

## Native MLX project

Choose only for Apple-native MLX/MLX-LM Python dependencies that directly need
unified memory or Metal-backed execution.

## Linux container

Choose for:

- databases, queues, vector stores and observability services
- stateless SAST/SCA/IaC/cloud scanners
- web UIs and APIs without native macOS requirements
- CI-equivalent build/test dependencies

Require loopback bindings, named data volumes, least privilege and immutable
image digests.

## Isolated Linux VM

Choose for:

- exploit development
- malware or untrusted binaries
- GDB/GEF/pwndbg and ptrace workflows
- kernel-sensitive work
- x86-specific behaviour
- tools requiring broad capabilities that would weaken the normal container
  runtime boundary
