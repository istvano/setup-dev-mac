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

# RDP, as a command-line client. On the host because a remote session is the host's
# display, keyboard and clipboard; a container has none of the three.
#
# This is what replaced remote-desktop-manager (ADR-047, withdrawn): one protocol, one
# command, no vault and no account. Use `sdl-freerdp`, which draws through SDL and
# needs nothing else. The formula also installs `xfreerdp`, which needs an X server
# this repository does not install — it fails with a $DISPLAY error, by design.
#
# Two things ride along that are not the client: `sfreerdp-server` and
# `freerdp-proxy`. Neither is started and no launchd service is shipped. It also
# pulls in ffmpeg and the X11 client libraries as dependencies. See ADR-050.
brew "freerdp" # RDP client for Windows and xrdp hosts, run as `sdl-freerdp`; stores no credentials.

# Terminal conveniences, opt-in rather than in core (ADR-053). On the host because each
# one inspects or moves host state: processes, the filesystem and outbound ssh.
#
# htop is a second tool for btop's job. ADR-022 forbids that in the DEFAULT profile,
# which keeps btop alone; here it is permitted, as iterm2 is beside ghostty above.
# rsync is here for the same reason as the other two: the default is capped at 70
# entries and none of the three carries a by-default argument strong enough to raise it.
brew "htop"               # Interactive process viewer whose keys match every Linux host reached by ssh.
brew "midnight-commander" # Two-pane terminal file manager (mc), with built-in sftp to remote hosts.
brew "rsync"              # Upstream rsync 3.x; /usr/bin/rsync is openrsync, without --mkpath or -X.

# Slack's desktop client. On the host because it is a GUI holding account sessions,
# with notifications, the microphone, the camera and screen sharing for huddles.
#
# An EXCEPTION to ADR-028, not a reading of it. That decision rejected Figma, Miro,
# Notion and Linear as browser applications wrapped in Electron, on the ground that
# the isolated browser contexts already reach them — and Slack is the same kind of
# application, reachable the same way. It is here because the operator chose the
# desktop client over a browser tab, and ADR-051 records that as a choice rather
# than dressing it as a distinction.
#
# It asks for Microphone, Camera and Screen Recording when a huddle needs them. The
# cask carries auto_updates, so versions arrive outside `brew upgrade` and outside
# ./script/update-report. Telemetry has no opt-out verified here (ADR-046).
cask "slack" # Slack desktop client; an Electron-wrapped web app, installed as a stated exception to ADR-028.

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

# OpenAI's ChatGPT desktop app — the current one, which merged Chat, Work and Codex.
# Not `chatgpt-classic`, the superseded native app kept alive under its own token, and
# not `chatgpt-atlas`: that is their browser, discontinued upstream on 2026-08-26 and
# DISABLED in Homebrew, so it would fail ./script/check-tokens.
#
# A SECOND EXCEPTION to ADR-028, on the same footing as slack above and no better.
# Electron was confirmed from the installed bundle rather than from reporting:
# ElectronAsarIntegrity in Info.plist, `Codex Framework.framework`, app.asar.unpacked,
# bundle id com.openai.codex, 1.7 GB, updated by Sparkle. So the isolated browser
# contexts reach chatgpt.com the same way ADR-028 says they do, and nothing about this
# app passes that rule on the merits. It is here because the operator chose it after
# being shown the conflict. See ADR-052.
#
# REQUIRES ACCESSIBILITY for "Work with Apps", which reads the last 200 lines of any
# open terminal pane (Terminal, iTerm2, Warp) plus editor content, and that content
# becomes chat history and leaves the machine. On a workstation holding credentials,
# client work and security tooling, terminal scrollback is among the most sensitive
# things on it. Installing grants none of this — the feature needs an in-app toggle AND
# a System Settings grant — and the declared posture is that it stays OFF here. See
# docs/MANUAL-SECURITY.md section 13.
#
# Two things ride along inside the bundle. `codex-cli` is codex 0.163.0-alpha.11, a
# PRERELEASE of the stable 0.163.0 that dev declares as a cask; it is not on PATH, so
# it wins no race, but Sparkle updates it outside the reviewed flow. `cua_node` is a
# vendored node v24.21.0 with corepack for the computer-use component — mise pins node
# 24, so the major agrees and ADR-021 is not breached, but it is a runtime nobody here
# manages.
#
# A fourth MCP client the allowlist does not reach, after codex, opencode and the
# Claude desktop app: connectors arrive through Developer Mode, which OpenAI documents
# as beta, "powerful but dangerous", and unverified by them (ADR-029).
#
# Telemetry has two channels. Training on content CAN be turned off — Settings > Data
# Controls > "Improve the model for everyone" — but that is an ACCOUNT setting syncing
# across devices, not something this repository can write. Usage diagnostics have no
# documented opt-out (ADR-046).
cask "chatgpt" # OpenAI's ChatGPT desktop app; an Electron-wrapped web app, installed as a stated exception to ADR-028.
