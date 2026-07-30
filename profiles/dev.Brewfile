cask "visual-studio-code" # Native editor and devcontainer client.
cask "zed"                # Fast native secondary editor.
cask "codex"              # OpenAI Codex CLI for repository-aware terminal development.
cask "claude-code"        # Anthropic Claude Code CLI for repository-aware terminal development.
brew "opencode"           # Provider-agnostic terminal coding agent; MIT.

# Language runtimes come from mise, not Homebrew. mise manages Rust by driving
# rustup and installing rustup itself when absent, so a second Rust installer
# would only add a place for the toolchain version to disagree. See ADR-021.
# Node, Go, Java, Rust and pnpm are declared in chezmoi/dot_config/mise/config.toml.tmpl.

brew "shellcheck"         # Native static analysis for frequently edited host shell scripts.
brew "shfmt"              # Deterministic formatter for repository shell scripts.
brew "actionlint"         # Native static validation for local GitHub Actions editing.
brew "yamllint"           # Local YAML syntax and style validation for repository work.
#brew "mkcert"             # Locally trusted development certificates; only needed when serving HTTPS.

# No pre-commit framework. Its hooks cost ~2.4s on every commit and grew with
# history, because a full-history secret scan ran each time. ./script/test is the
# gate; CI enforces it on every push. See ADR-023.
