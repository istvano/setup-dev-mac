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
# Moved here from the opt-in security-scan profile by ADR-040. Containers and
# Kubernetes are the default purpose now (ADR-037, ADR-038), so linting a Dockerfile
# and scanning an image or a manifest are part of authoring, not a specialist
# excursion — the same reasoning that moved kubernetes into the default set. They sit
# with the other validators above rather than in a scanner profile because what they
# validate is this repository's own output.
#
# Only these two moved. ADR-022 permits one tool per job, and the rest of
# security-scan overlaps something already present: grype re-scans what trivy already
# scans, osv-scanner duplicates its dependency checking, and trufflehog duplicates
# gitleaks in core. syft and dive stay opt-in as release and debugging tools rather
# than daily ones.
brew "hadolint"           # Dockerfile linter, used while authoring project images.
brew "trivy"              # Scans images, filesystems and IaC for vulnerabilities and misconfiguration.
#brew "mkcert"             # Locally trusted development certificates; only needed when serving HTTPS.

# No pre-commit framework. Its hooks cost ~2.4s on every commit and grew with
# history, because a full-history secret scan ran each time. ./script/test is the
# gate; CI enforces it on every push. See ADR-023.
