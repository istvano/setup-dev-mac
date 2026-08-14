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
# The interactive shell itself is a mutually exclusive choice: shell-zsh.Brewfile
# or shell-fish.Brewfile, selected by --shell. Everything below is shell-agnostic.

# Core CLI
brew "ripgrep"   # Fast recursive text and regular-expression search.
brew "fd"        # Fast, user-friendly filesystem search.
brew "fzf"       # Interactive fuzzy finder for shell workflows.
brew "bat"       # Syntax-highlighted file viewer and cat replacement.
brew "eza"       # Modern directory listing with Git metadata; also provides --tree.
brew "zoxide"    # Frecency-based directory navigation.
brew "atuin"     # Local SQLite-backed shell history with contextual search.
brew "jq"        # Command-line JSON query and transformation tool.
brew "yq"        # Command-line YAML, JSON and XML processor.
brew "git-delta" # Syntax-highlighted pager for Git diffs.
brew "btop"      # Interactive dashboard for host processes, CPU, memory, disk and network.
brew "just"      # Thin command runner for repository workflows.
# A stated exception to ADR-022: curl stays for scripting, xh for interactive
# API work, which is a daily task here. Two clients, deliberately.
brew "xh"        # Ergonomic HTTP client for talking to remote APIs by hand.
brew "trash"     # Moves files to the macOS Trash instead of unlinking them.

# Optional conveniences. Enable individually; none is needed to develop, and each
# has a capable replacement already present or built into macOS.
#brew "dust"      # Visual disk-usage breakdown; `du -sh` covers occasional use.
#brew "tealdeer"  # Offline tldr pages.
#brew "watchexec" # Re-runs commands in response to host filesystem changes.
# Enabled, and no longer "only when a repository uses LFS". Model repositories do —
# Hugging Face stores weights in LFS — and this workstation exists partly for AI
# development. Cloning such a repository without it silently yields pointer files
# instead of weights, which presents as a corrupt model rather than a missing tool.
#
# Installing the package is only half of it: the clean/smudge/process filters must
# exist in Git's configuration too. Those are declared in chezmoi/dot_gitconfig.tmpl
# rather than left to a `git lfs install` run-once hook, because chezmoi already owns
# that file and a hook would fight it. See ADR-039.
brew "git-lfs"   # Large-file storage, used by model repositories.

# Editing
brew "neovim"    # Terminal editor for SSH, recovery and other no-GUI sessions.

# Version control and security baseline
brew "git"        # Distributed version-control command-line client.
brew "gh"         # GitHub command-line client for repository workflows.
brew "age"        # Small file-encryption CLI retained as part of the bootstrap trust set.
brew "sops"       # Encrypts structured secret files with the age identity created at first apply.
brew "gitleaks"   # Fast native scanner for secrets in source and Git history.

# Commit signing. Host-only: gpg-agent needs a GUI pinentry and, for a key on a
# hardware token, direct smartcard access that a container cannot be given.
brew "gnupg"        # OpenPGP implementation used to sign commits and tags.
brew "pinentry-mac" # GUI passphrase prompt that can cache the key in the macOS Keychain.
