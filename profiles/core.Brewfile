# Bootstrap and configuration
brew "mise"      # Project-local runtime and tool-version manager.
brew "uv"        # Fast Python package, environment and version manager.
brew "direnv"    # Per-directory environment activation with explicit approval.
brew "chezmoi"   # Idempotent dotfile and workstation configuration manager.

# Terminal and shell
brew "starship"  # Cross-shell prompt with project and version-control context.
brew "tmux"      # Persistent terminal session multiplexer.
cask "ghostty"   # Native GPU-accelerated terminal emulator.
cask "font-jetbrains-mono-nerd-font" # Coding font with terminal icon glyphs.
brew "zsh-autosuggestions"     # Inline history suggestions for the interactive host shell.
brew "zsh-syntax-highlighting" # Highlights invalid commands before they are executed.

# Core CLI
brew "ripgrep"   # Fast recursive text and regular-expression search.
brew "fd"        # Fast, user-friendly filesystem search.
brew "fzf"       # Interactive fuzzy finder for shell workflows.
brew "bat"       # Syntax-highlighted file viewer and cat replacement.
brew "eza"       # Modern directory listing with Git metadata.
brew "zoxide"    # Frecency-based directory navigation.
brew "atuin"     # Local SQLite-backed shell history with contextual search.
brew "jq"        # Command-line JSON query and transformation tool.
brew "yq"        # Command-line YAML, JSON and XML processor.
brew "git-delta" # Syntax-highlighted pager for Git diffs.
brew "htop"      # Interactive viewer for frequently inspecting host processes.
brew "btop"      # Interactive dashboard for host CPU, memory, disk and network resources.
brew "tree"      # Hierarchical directory listing utility.
brew "xh"        # Fast HTTP client compatible with common HTTPie workflows.
brew "just"      # Thin command runner for repository workflows.
brew "wget"      # Non-interactive HTTP download client relied on by common scripts.
brew "dust"      # Fast disk-usage breakdown for triaging a 4 TB host volume.
brew "tealdeer"  # Offline tldr pages, usable without network access.
brew "watchexec" # Re-runs commands in response to host filesystem changes.
brew "trash"     # Moves files to the macOS Trash instead of unlinking them.

# Editing
brew "neovim"    # Terminal editor for SSH, recovery and other no-GUI sessions.

# Version control and security baseline
brew "git"        # Distributed version-control command-line client.
brew "git-lfs"    # Large-file storage support for repositories that require it.
brew "gh"         # GitHub command-line client for repository workflows.
brew "difftastic" # Structural, syntax-aware diff complementing git-delta.
brew "age"        # Small file-encryption CLI retained as part of the bootstrap trust set.
brew "gitleaks"   # Fast native scanner for secrets in source and Git history.

# Commit signing. Host-only: gpg-agent needs a GUI pinentry and, for a key on a
# hardware token, direct smartcard access that a container cannot be given.
brew "gnupg"        # OpenPGP implementation used to sign commits and tags.
brew "pinentry-mac" # GUI passphrase prompt that can cache the key in the macOS Keychain.
