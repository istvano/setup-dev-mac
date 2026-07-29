#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib.sh
source "$ROOT/tests/lib.sh"

# refute_match replaces bare `! grep`, which disabled errexit and treated
# grep's error status (a renamed or missing file) as a passing assertion.
refute_match '^[[:space:]]*(brew|cask) "(ollama|llama\.cpp|pytorch)"' "$ROOT/profiles"
refute_match '^[[:space:]]*(brew|cask) "mlx' "$ROOT/profiles"
[[ ! -e "$ROOT/profiles/ai.Brewfile" ]]
refute_match '(^|[,"[:space:]])ai([,"[:space:]]|$)' \
  "$ROOT/bootstrap" "$ROOT/script/render-brewfile" "$ROOT/justfile" \
  "$ROOT/chezmoi/.chezmoi.toml.tmpl"
refute_match 'syncNativeAi|pythonVersion' \
  "$ROOT/bootstrap" "$ROOT/script" "$ROOT/chezmoi"
assert_match '^brew "atuin".*#' "$ROOT/profiles/core.Brewfile"
assert_match 'atuin init zsh --disable-ai' "$ROOT/chezmoi/dot_zshrc.tmpl"
assert_match '^auto_sync = false$' "$ROOT/chezmoi/dot_config/atuin/config.toml"
python3 - "$ROOT/chezmoi/dot_config/atuin/config.toml" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as config:
    tomllib.load(config)
PY
[[ ! -e "$ROOT/containers" ]]
[[ ! -e "$ROOT/chezmoi/private_dot_config/security-ai-workstation/containers" ]]
echo 'Placement policy: OK'
