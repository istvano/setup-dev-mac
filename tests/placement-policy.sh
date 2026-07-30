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

# fzf and Atuin both bind Ctrl-R and the later initialisation wins. Atuin is the
# history store this workstation is built around, so it must come last. Getting
# this wrong leaves a working shell with the wrong history tool, which is why it
# needs a test rather than a comment.
zshrc="$ROOT/chezmoi/dot_zshrc.tmpl"
fzf_line="$(grep -n 'fzf --zsh' "$zshrc" | head -n 1 | cut -d: -f1)"
atuin_line="$(grep -n 'atuin init zsh' "$zshrc" | head -n 1 | cut -d: -f1)"
[[ -n "$fzf_line" && -n "$atuin_line" ]] || {
  echo 'Could not locate the fzf and atuin initialisation lines.' >&2
  exit 1
}
((atuin_line > fzf_line)) || {
  echo "dot_zshrc.tmpl: atuin (line $atuin_line) must initialise after fzf" \
    "(line $fzf_line), or fzf takes over Ctrl-R." >&2
  exit 1
}

# The keymap must be explicit: zsh selects viins whenever EDITOR contains "vi",
# and this configuration sets EDITOR=nvim.
assert_match '^bindkey -e$' "$zshrc"
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
