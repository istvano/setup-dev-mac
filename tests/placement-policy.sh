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

# Ghostty's scrollback limit: the hazard is units, not spelling.
#
# `scrollback-limit` (and its 1.4 name `scrollback-limit-bytes`) counts BYTES.
# `scrollback-limit-lines` counts lines and exists only from 1.4, while the cask
# installs 1.3.1 and rejects it as unknown.
#
# So the assertion is on magnitude, not on which key is used. The real defect was
# `scrollback-limit = 10000` — a value plausible as a line count, catastrophic as
# a byte count — and naming a key cannot catch that. This also stays correct once
# a 1.4 upgrade makes the lines key available.
ghostty="$ROOT/chezmoi/dot_config/ghostty/config.tmpl"

# `|| true` is required: errexit plus pipefail turns a no-match grep into a failed
# assignment, and "this key is absent" is a legitimate answer here, not an error.
scrollback_value() {
  local line
  line="$(grep -E "^$1[[:space:]]*=" "$ghostty" | head -n 1 || true)"
  [[ -n "$line" ]] || return 0
  sed -E 's/.*=[[:space:]]*//' <<<"$line"
}

# `scrollback-limit(-bytes)?` cannot match `scrollback-limit-lines`: `-lines`
# does not satisfy the `[[:space:]]*=` that follows.
sb_bytes="$(scrollback_value 'scrollback-limit(-bytes)?')"
sb_lines="$(scrollback_value 'scrollback-limit-lines')"

[[ -n "$sb_bytes" || -n "$sb_lines" ]] || {
  echo 'ghostty/config.tmpl sets no scrollback limit at all.' >&2
  exit 1
}
for value in "$sb_bytes" "$sb_lines"; do
  [[ -z "$value" || "$value" =~ ^[0-9]+$ ]] || {
    echo "ghostty/config.tmpl: non-numeric scrollback value: $value" >&2
    exit 1
  }
done
if [[ -n "$sb_bytes" ]] && ((sb_bytes < 1000000)); then
  echo "ghostty/config.tmpl: scrollback-limit = $sb_bytes is measured in BYTES," >&2
  echo "so this is under a megabyte. That is a line count written into a byte" >&2
  echo "key — the original defect. Use bytes, or scrollback-limit-lines on 1.4+." >&2
  exit 1
fi
if [[ -n "$sb_lines" ]] && ((sb_lines > 1000000)); then
  echo "ghostty/config.tmpl: scrollback-limit-lines = $sb_lines is a line count," >&2
  echo "and this looks like a byte value written into the lines key." >&2
  exit 1
fi

# shell-integration must follow the selection. Hardcoding a shell here is the
# quiet failure: Ghostty falls back to detection, so the terminal still works and
# only the cursor, sudo and title features silently stop matching the real shell.
assert_match '^shell-integration = \{\{ \.shell \}\}$' "$ghostty"

# fish applies /etc/paths and /etc/paths.d only as a login shell, so dropping
# --login leaves a working terminal whose PATH is quietly missing entries.
#
# The prefix comes from the brew-prefix template rather than a literal, because
# Homebrew lives at /opt/homebrew on Apple Silicon and /usr/local on Intel.
# tests/chezmoi-templates.sh checks what that actually renders to.
assert_match '^command = \{\{ template "brew-prefix" \. \}\}/bin/fish --login$' "$ghostty"

# Ghostty theme names use its own spelling, which is not this repository's.
#
# `ghostty +list-themes` prints "Catppuccin Mocha" — capitalised, space
# separated. Written lowercase-hyphenated, Ghostty refuses to start. This asserts
# the shape only; the machine-specific check is `ghostty +validate-config`, which
# needs Ghostty installed and is in docs/TESTING.md.
theme_line="$(grep -m1 '^theme = ' "$ghostty" || true)"
[[ -n "$theme_line" ]] || {
  echo 'ghostty/config.tmpl sets no theme.' >&2
  exit 1
}
if [[ "$theme_line" =~ [a-z]+-[a-z]+ ]]; then
  echo "ghostty/config.tmpl uses a hyphenated theme name:" >&2
  echo "  $theme_line" >&2
  echo 'Ghostty names themes as +list-themes prints them, e.g. "Catppuccin Mocha".' >&2
  echo 'A name it cannot resolve stops Ghostty starting entirely.' >&2
  exit 1
fi

# Nothing may assume the Apple Silicon prefix as the only one.
#
# Hardcoding /opt/homebrew made every shell activation and apply hook a silent
# no-op on an Intel Mac: the guard simply tested false, so Homebrew was never put
# on PATH and the failure surfaced later as "command not found" for tools that
# were in fact installed. Anything naming that path must name /usr/local too.
while IFS= read -r offender; do
  file="${offender%%:*}"
  case "$file" in
    *lib/common.sh | *docs/* | *.md) continue ;; # prose and the definition itself
  esac
  grep -q '/usr/local' "$file" || {
    echo "$file names /opt/homebrew without /usr/local, so it assumes Apple" >&2
    echo "Silicon. Homebrew installs to /usr/local on Intel. Use brew_prefix," >&2
    echo 'the "brew-shellenv" template, or check both paths.' >&2
    exit 1
  }
done < <(grep -rl '/opt/homebrew' "$ROOT/script" "$ROOT/chezmoi" "$ROOT/bootstrap" 2>/dev/null || true)

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
# The trailing "Mono" is required: the cask ships only monospaced variants, and
# "JetBrainsMono Nerd Font" resolves to nothing. Ghostty then falls back silently.
assert_match '^font-family = JetBrainsMono Nerd Font Mono$' "$ghostty"
assert_match '^cask "font-jetbrains-mono-nerd-font"' "$ROOT/profiles/core.Brewfile"

# The symbols-only font is the reason the fonts profile is worth having: it is
# glyphs alone, so it upgrades any unpatched font by fallback.
assert_match '^cask "font-symbols-only-nerd-font"' "$ROOT/profiles/fonts.Brewfile"

# `ghostty` has to be on PATH, because the documentation invokes it.
#
# The cask ships an app, manpages and completions but NO binary artifact, so
# `ghostty +show-config` — the resolver ADR-030 tells the reader to trust over the
# config file — was not a command that existed on macOS. The symlink below makes
# the documentation true. If it goes, every one of those instructions breaks
# while the file still reads as correct.
ghostty_link="$ROOT/chezmoi/dot_local/bin/symlink_ghostty"
[[ -f "$ghostty_link" ]] || {
  echo 'chezmoi/dot_local/bin/symlink_ghostty is missing, so ghostty is not on' >&2
  echo 'PATH and every documented "ghostty +show-config" is a broken command.' >&2
  exit 1
}
assert_match '^/Applications/Ghostty\.app/Contents/MacOS/ghostty$' "$ghostty_link"
assert_match '^auto_sync = false$' "$ROOT/chezmoi/dot_config/atuin/config.toml"
# TOML syntax check. tomllib is Python 3.11+, and macOS's Command Line Tools ship
# 3.9 — so the parser cannot be assumed on the platform this repository targets,
# even though every CI runner has it. Exit 42 is a sentinel for "no parser here",
# which has to be distinguished from a real parse failure; treating them alike
# would let a malformed config pass on any machine without tomllib.
toml_status=0
python3 - "$ROOT/chezmoi/dot_config/atuin/config.toml" <<'PY' || toml_status=$?
import sys

try:
    import tomllib
except ModuleNotFoundError:
    try:
        import tomli as tomllib
    except ModuleNotFoundError:
        raise SystemExit(42)

with open(sys.argv[1], "rb") as config:
    tomllib.load(config)
PY
case "$toml_status" in
  0) ;;
  42)
    if [[ "${REQUIRE_LINTERS:-0}" == "1" ]]; then
      echo 'A TOML parser is required when REQUIRE_LINTERS=1: Python 3.11+ for' >&2
      echo 'tomllib, or tomli. macOS Command Line Tools ship Python 3.9.' >&2
      exit 1
    fi
    echo '  atuin config.toml: no TOML parser (needs Python 3.11+), check skipped'
    ;;
  *) exit "$toml_status" ;;
esac
[[ ! -e "$ROOT/containers" ]]
[[ ! -e "$ROOT/chezmoi/private_dot_config/security-ai-workstation/containers" ]]
echo 'Placement policy: OK'
