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

# ZSH_HIGHLIGHT_MAXLENGTH is read when zsh-syntax-highlighting is sourced. Set
# after that point it has no effect, and the only symptom is a slow prompt.
maxlen_line="$(grep -n '^ZSH_HIGHLIGHT_MAXLENGTH=' "$zshrc" | head -n 1 | cut -d: -f1)"
highlight_line="$(grep -n 'zsh-syntax-highlighting.zsh' "$zshrc" | head -n 1 | cut -d: -f1)"
[[ -n "$maxlen_line" && -n "$highlight_line" ]] || {
  echo 'Could not locate ZSH_HIGHLIGHT_MAXLENGTH and the syntax-highlighting source line.' >&2
  exit 1
}
((maxlen_line < highlight_line)) || {
  echo "dot_zshrc.tmpl: ZSH_HIGHLIGHT_MAXLENGTH (line $maxlen_line) must be set" \
    "before zsh-syntax-highlighting is sourced (line $highlight_line)." >&2
  exit 1
}

# The same Control-R collision exists in fish: fzf's fish bindings run
# `bind \cr fzf-history-widget` and Atuin binds Control-R too, so the file that
# gained the assertion for zsh needs it for the shell that shares the hazard.
fishrc="$ROOT/chezmoi/dot_config/fish/config.fish.tmpl"
fish_fzf_line="$(grep -n 'fzf --fish' "$fishrc" | head -n 1 | cut -d: -f1)"
fish_atuin_line="$(grep -n 'atuin init fish' "$fishrc" | head -n 1 | cut -d: -f1)"
[[ -n "$fish_fzf_line" && -n "$fish_atuin_line" ]] || {
  echo 'Could not locate the fzf and atuin initialisation lines in config.fish.tmpl.' >&2
  exit 1
}
((fish_atuin_line > fish_fzf_line)) || {
  echo "config.fish.tmpl: atuin (line $fish_atuin_line) must initialise after fzf" \
    "(line $fish_fzf_line), or fzf takes over Control-R." >&2
  exit 1
}
assert_match 'atuin init fish --disable-ai' "$fishrc"

# fish_add_path ignores a directory that does not exist, and says so only under
# --verbose. ~/.local/bin is on fish's PATH solely because chezmoi creates it for
# the executables below. Emptying that directory would leave zsh's unconditional
# prepend working and silently drop the entry for fish only.
# [$] rather than \$ so shellcheck does not read the pattern as an expansion.
assert_match '^fish_add_path -g [$]HOME/[.]local/bin$' "$fishrc"
compgen -G "$ROOT/chezmoi/dot_local/bin/*" >/dev/null || {
  echo 'chezmoi/dot_local/bin is empty, so ~/.local/bin is no longer created and' >&2
  echo 'fish_add_path in config.fish.tmpl would silently skip it.' >&2
  exit 1
}

# Ghostty's scrollback-limit is measured in BYTES and was renamed to
# scrollback-limit-bytes in 1.4. The bare key set to a line count silently gave a
# ~10 KB buffer against a 50 MB default, so require the explicit lines key.
ghostty="$ROOT/chezmoi/dot_config/ghostty/config.tmpl"
assert_match '^scrollback-limit-lines[[:space:]]*=' "$ghostty"
refute_match '^scrollback-limit[[:space:]]*=' "$ghostty"

# shell-integration must follow the selection. Hardcoding a shell here is the
# quiet failure: Ghostty falls back to detection, so the terminal still works and
# only the cursor, sudo and title features silently stop matching the real shell.
assert_match '^shell-integration = \{\{ \.shell \}\}$' "$ghostty"

# fish applies /etc/paths and /etc/paths.d only as a login shell, so dropping
# --login leaves a working terminal whose PATH is quietly missing entries.
assert_match '^command = /opt/homebrew/bin/fish --login$' "$ghostty"

# Ghostty's font-family must be installed by a fragment that is always selected.
#
# An unknown font name is not an error: Ghostty falls back to a default silently,
# so the terminal opens, text renders, and only the prompt and eza glyphs become
# replacement boxes — a configuration problem that reads as a rendering problem.
# The fonts profile is opt-in, so the primary font has to come from core.
#
# Asserted as a literal pair rather than derived from one to the other. Homebrew's
# word splitting is not mechanical — "JetBrainsMono Nerd Font" is
# font-jetbrains-mono-nerd-font, not font-jetbrainsmono-nerd-font, and
# "MesloLGS Nerd Font" is font-meslo-lg-nerd-font — so any normalisation clever
# enough to pair them is also wrong often enough to fail on a valid change.
# Changing the font must fail both lines and be re-paired deliberately.
assert_match '^font-family = JetBrainsMono Nerd Font$' "$ghostty"
assert_match '^cask "font-jetbrains-mono-nerd-font"' "$ROOT/profiles/core.Brewfile"

# The symbols-only font is the reason the fonts profile is worth having: it is
# glyphs alone, so it upgrades any unpatched font by fallback.
assert_match '^cask "font-symbols-only-nerd-font"' "$ROOT/profiles/fonts.Brewfile"
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
