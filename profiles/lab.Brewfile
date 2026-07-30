# Local lab environments, and the isolated Linux VM that docs/ARCHITECTURE.md
# names as an execution domain.
#
# Until this profile existed the placement matrix routinely sent exploit
# development, malware analysis, untrusted binaries and x86-specific work "to
# the VM" while no VM tooling was installed anywhere. Colima's VM is a container
# runtime, not an isolation boundary. See ADR-027.
#
# Host placement is required: these are hypervisor frontends needing
# Virtualization.framework and direct hardware access.
brew "lima"    # Scriptable, disposable Linux VMs defined in declarative YAML.
cask "utm"     # QEMU-backed GUI VMs, including x86_64 emulation on Apple Silicon.
brew "ansible" # Agentless configuration management for lab VMs and remote hosts.
