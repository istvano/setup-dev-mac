cask "firefox@developer-edition" # Optional native browser with an isolated development profile.
cask "google-chrome"             # Optional native browser for compatibility and profile separation.
#cask "yubico-authenticator"      # Optional native UI for YubiKey OATH integration.
cask "tailscale-app"             # Optional native VPN client requiring macOS network integration.
#cask "stats"                     # Menu-bar hardware monitor: polls sensors continuously for a reading btop gives on demand.
cask "iina"                      # Optional native macOS media player.
#cask "keka"                      # Optional native archive creation and extraction utility.

# Desktop utilities. Each expands the permissions or data the host holds, so the
# caveat is stated here rather than discovered after installation.
#cask "maccy"             # Clipboard history. Stores whatever is copied: exclude password-manager and terminal sources.
#cask "shottr"            # Free screenshot and annotation tool; overlaps the paid cleanshot in paid.Brewfile.

# Alternative terminal. ADR-022 requires one tool per job in the *default*
# profile, so a second terminal is permitted here but not in core, where ghostty
# remains the one that the ghostty config in chezmoi/ is written for.
cask "iterm2"            # Mature terminal emulator; alternative to ghostty, not a replacement for it.

# Screen recording is covered by cleanshot in paid.Brewfile and by the built-in
# Cmd+Shift+5. Kap was evaluated and rejected: last released October 2022, and it
# bundles Electron 13.6.9 (Chromium 91, unpatched since 2021) while holding
# Screen Recording permission. See ADR-026.
cask "obs"               # Free GPL alternative if a non-paid recorder is needed; heavy for short clips.
#cask "jordanbaird-ice"   # Menu-bar organiser for a crowded status area.
cask "pearcleaner"       # Application remover. Needs broad filesystem access to find leftover support files.
cask "latest"            # Reports updates for applications Homebrew does not manage.

# OpenVPN, as the upstream command line rather than a GUI client. On the host because
# a VPN client is the host's routing table and a utun interface; a container or VM
# would tunnel only itself.
#
# Not a second tool for tailscale-app's job: Tailscale speaks WireGuard to a tailnet
# and cannot reach an OpenVPN server. The CLI rather than Tunnelblick or OpenVPN
# Connect because both of those leave a privileged helper installed between
# connections, and this leaves nothing: it runs as root under `sudo` for the length
# of one connection. See ADR-049.
#
# The formula ships a launchd service definition. It is NOT started — AGENTS.md
# forbids automatic network-service enablement, and a tunnel that comes up at boot is
# exactly that. Profiles and credentials live outside this repository.
brew "openvpn" # OpenVPN 2.x client run on demand under sudo; no helper or service left installed.

# Anthropic's Claude desktop app: one application with three tabs — Chat, Cowork and
# Code — where the Code tab IS Claude Code. On the host because it is a native GUI
# holding an account session; there is no container form of it worth having.
#
# NOT a second tool for the job `claude-code` does in dev, and the distinction matters
# because ADR-022's carve-out does not cover this one. That carve-out permits several
# coding agents because each reaches a DIFFERENT provider; this reaches the same
# provider as claude-code. What earns it a place is the surface rather than the
# backend: the Code tab does overlap the CLI, and Chat and Cowork do not. An opt-in
# fragment is where a deliberate second surface already lives — iterm2 beside core's
# ghostty. See ADR-048.
#
# Its Code tab's MCP servers are OUTSIDE mcp/managed-settings.json. That file governs
# Claude Code in the terminal, in IDE extensions and in the Agent SDK; the desktop app
# supplies and locks its sessions' servers itself, from claude.ai organisation
# settings. So this is a third client the allowlist does not reach, after codex and
# opencode, and it is reviewed by hand in script/hardening-check (ADR-029, ADR-048).
#
# Telemetry has NO documented opt-out for the first-party app. The CLI's variables are
# not documented as applying to it, so none is exported on spec — a variable nothing
# reads is worse than none (ADR-046). The cask also carries auto_updates, so versions
# arrive outside `brew upgrade` and outside ./script/update-report.
cask "claude" # Anthropic's Claude desktop app: Chat, Cowork and the Code tab in a GUI.
