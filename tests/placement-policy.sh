#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
! grep -R -E '^[[:space:]]*(brew|cask) "(ollama|llama\.cpp|pytorch)"' "$ROOT/profiles"
! grep -R -E '^[[:space:]]*(brew|cask) "mlx' "$ROOT/profiles"
[[ ! -e "$ROOT/profiles/ai.Brewfile" ]]
! grep -R -E '(^|[,"[:space:]])ai([,"[:space:]]|$)' \
  "$ROOT/bootstrap" "$ROOT/script/render-brewfile" "$ROOT/justfile" \
  "$ROOT/chezmoi/.chezmoi.toml.tmpl"
! grep -R -E 'syncNativeAi|pythonVersion' \
  "$ROOT/bootstrap" "$ROOT/script" "$ROOT/chezmoi"
grep -q '^brew "atuin".*#' "$ROOT/profiles/core.Brewfile"
grep -q 'atuin init zsh --disable-ai' "$ROOT/chezmoi/dot_zshrc.tmpl"
grep -q '^auto_sync = false$' "$ROOT/chezmoi/dot_config/atuin/config.toml"
python3 - "$ROOT/chezmoi/dot_config/atuin/config.toml" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as config:
    tomllib.load(config)
PY
[[ ! -e "$ROOT/containers" ]]
[[ ! -e "$ROOT/chezmoi/private_dot_config/security-ai-workstation/containers" ]]
echo 'Placement policy: OK'
