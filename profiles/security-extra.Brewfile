# Host-network and cryptographic inspection. Opt-in rather than default: these
# are tools for doing security work, not for keeping the workstation secure.
brew "nmap"    # Host-network discovery, port scanning and service inspection.
brew "cosign"  # Verifies Sigstore signatures on images and release artefacts before they are trusted.
brew "step"    # Optional host CLI for explicit smallstep PKI workflows.

# Intercepting proxies. Both terminate TLS by installing a trusted root CA, which
# is the highest-privilege thing on this list: while trusted, that certificate
# can decrypt any TLS session on the machine. Install the CA only when actively
# debugging, and remove it from the keychain afterwards rather than leaving it.
cask "burp-suite" # Optional native GUI for interactive web security testing.
cask "mitmproxy"  # Scriptable HTTP/HTTPS interception with a TUI and web UI; MIT, and does not self-update.
#cask "proxyman"   # Native GUI alternative to mitmproxy; closed source, free tier, and self-updates outside brew.

# Hardware security keys. Host-only: these need direct USB and PC/SC access that
# a Linux container on macOS cannot be given.
# brew "ykman"              # YubiKey configuration CLI complementing the Yubico Authenticator GUI.
# brew "age-plugin-yubikey" # Backs age and SOPS identities with a YubiKey instead of an on-disk key.
# cask "secretive"          # Free SSH agent holding keys in the Secure Enclave; signs commits without an on-disk key.

# macOS persistence, process and privacy monitoring (Objective-See).
cask "oversight"     # Optional native monitor for microphone and camera activation.
cask "netiquette"    # Optional native per-process network connection monitor.
