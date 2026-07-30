# Nerd Fonts — patched monospace fonts from https://github.com/ryanoasis/nerd-fonts
#
# These casks download the release archives from that project directly and verify
# a pinned SHA-256; they live in homebrew/cask, so no tap is added. The upstream
# `install.sh` is deliberately not used: it clones a multi-gigabyte repository and
# runs a remote script outside the Homebrew trust boundary that SECURITY.md draws
# (ADR-020, ADR-032).
#
# font-jetbrains-mono-nerd-font is NOT here. It stays in core.Brewfile because
# dot_config/ghostty/config names it as font-family, so the terminal depends on it
# whether or not this profile is selected.
#
# A font executes nothing, opens no port and needs no permission, so this list is
# less restrictive than the software profiles. It is still curated rather than
# complete: homebrew/cask carries 71 Nerd Font casks and installing all of them
# only makes the font picker unusable.

# The one to install even if you want no other. It is glyphs only, with no Latin
# alphabet, so it works as a FALLBACK for any font: name your real font first and
# this second in Ghostty's font-family, and an unpatched font gains every Nerd
# Font icon without being replaced.
cask "font-symbols-only-nerd-font" # Nerd Font glyphs alone, for use as a fallback.

cask "font-meslo-lg-nerd-font"      # Reference font for prompt glyph problems; what starship issues are reproduced against.
cask "font-hack-nerd-font"          # High legibility at small sizes for long log and diff sessions.
cask "font-fira-code-nerd-font"     # Programming ligatures.
cask "font-caskaydia-cove-nerd-font" # Cascadia Code with ligatures and a cursive italic for comments.
cask "font-iosevka-nerd-font"       # Narrow, fitting more columns for side-by-side diffs on one screen.

# Further alternatives. Each is a matter of taste rather than capability, so they
# are listed for discoverability instead of installed.
#cask "font-commit-mono-nerd-font"     # Neutral, dense, designed for code.
#cask "font-geist-mono-nerd-font"      # Vercel's monospace.
#cask "font-sauce-code-pro-nerd-font"  # Source Code Pro.
#cask "font-monaspice-nerd-font"       # GitHub Monaspace; Nerd Fonts renames it Monaspice.
