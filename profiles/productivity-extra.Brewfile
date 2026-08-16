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
