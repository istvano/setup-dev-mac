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

# Remote connections. Holds RDP, VNC and SSH session definitions in one native
# client. On the host rather than in the VM because it needs the display, clipboard
# and Keychain integration a remote session is made of.
#
# Conditionally licensed, and here rather than in paid.Brewfile because nothing
# installed from this profile requires a licence to run: the Free edition covers
# individual use including commercial work, and only individual use — shared vaults,
# role-based access control and centralised management are paid tiers behind a 14-day
# trial, from the same installer. See ADR-047.
#
# It embeds its own credential vault. That does not breach the mutually-exclusive
# password-manager rule — no browser extension, no SSH agent, no CLI this repository
# calls — but it is a second place secrets live, so Bitwarden stays the system of
# record and this holds session entries only (ADR-047).
#
# Telemetry is ON by default and the opt-out is manual, as is the news fetch it shares
# a switch with: ADR-046, docs/MANUAL-SECURITY.md section 12. The cask also carries
# auto_updates, so versions arrive outside `brew upgrade` and outside
# ./script/update-report.
cask "remote-desktop-manager" # Multi-protocol remote connection manager for RDP, SSH and VNC.

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
