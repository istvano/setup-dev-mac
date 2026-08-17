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

# --- Intel support must stay removed (ADR-036).
#
# The assertion here used to be the OPPOSITE: anything naming /opt/homebrew had to
# name /usr/local too, so a hardcoded Apple Silicon prefix could not make every
# shell activation a silent no-op on an Intel Mac. Apple Silicon is now the only
# supported platform, so that requirement inverted rather than merely expired —
# /usr/local on this hardware is an x86_64 Homebrew under Rosetta, and falling back
# to it would put translated binaries on PATH while reporting success.
#
# What is checked now is that the removal cannot half-revert. The machinery came
# out of several files at once, and a partial restoration would leave a marker no
# script reads or a gap report nothing calls.
# Comments are excluded, and that is not a loophole — it is the difference between
# checking for an INVOCATION and checking for a word. Several files here now
# explain why platform-gaps was removed, so a plain grep matches the explanation
# and fails forever: a test nobody can make pass gets deleted, and then the real
# regression goes unnoticed. Same reason tests/vm.sh judges "$*" by code only.
while IFS= read -r offender; do
  echo "$offender" >&2
  echo 'script/platform-gaps is invoked but no longer exists (ADR-036). It' >&2
  echo 'reported what an Intel machine could not install.' >&2
  exit 1
done < <(
  awk '
    # This file is excluded from its own scan: the error message below names the
    # script, which would otherwise match and make the check unconditionally fail.
    # `next` on a FILENAME test rather than `nextfile`, which is not in every awk.
    FILENAME ~ /placement-policy\.sh$/ { next }
    /^[[:space:]]*#/ { next }
    /platform-gaps/ { print FILENAME ":" FNR ": " $0 }
  ' "$ROOT/bootstrap" "$ROOT/justfile" \
    "$ROOT"/script/* "$ROOT"/tests/*.sh 2>/dev/null || true
)
[[ ! -e "$ROOT/script/platform-gaps" ]] || {
  echo 'script/platform-gaps is back. It reported what an Intel machine could' >&2
  echo 'not install; with arm64 the only target it has nothing to report.' >&2
  exit 1
}
# The marker is only meaningful to a reader of platform-gaps, so a new one would be
# decoration that looks load-bearing.
#
# Matched on DECLARATION lines, which is the only place a marker means anything, and where
# ADR-013 documents it living: at the END of a purpose comment, as in
# `cask "lm-studio" # Local inference runtime. arm64-only`. The previous pattern required
# arm64-only to be the first token after `#`, so the marker could be reintroduced in
# exactly its documented form and the refutation would not fire.
#
# A blanket search would be wrong in the other direction: profiles/local-llm.Brewfile
# explains the removed platform-gaps in prose and names the marker while doing so. A check
# that cannot tell a declaration from the explanation of one fails on the correct file.
marker_lines="$(awk '
  /^[[:space:]]*(brew|cask) "/ && /arm64-only/ { printf "  %s:%d: %s\n", FILENAME, FNR, $0 }
' "$ROOT"/profiles/*.Brewfile)"
[[ -z "$marker_lines" ]] || {
  echo 'A package declaration carries an arm64-only marker:' >&2
  echo "$marker_lines" >&2
  echo 'Nothing reads it since script/platform-gaps was removed (ADR-036).' >&2
  exit 1
}

# No Rosetta Homebrew may be reintroduced as a fallback. Left unchecked, a
# well-meaning "support both prefixes" edit silently restores it, and the symptom is
# a translated toolchain on PATH that works and reports success.
#
# The pattern is the EXECUTABLE path, /usr/local/bin/brew, not the bare prefix.
# Four files now explain in prose why /usr/local is absent, and matching the word
# would flag every one of them — across shell comments, a fish comment and a Go
# template comment, which no single comment rule covers. The executable form
# appears only where the fallback would actually be reintroduced.
while IFS= read -r file; do
  case "$file" in
    # script/vm checks for Homebrew's ABSENCE in the guest, where naming both
    # prefixes is stricter rather than wrong.
    */script/vm) continue ;;
  esac
  echo "$file resolves /usr/local/bin/brew. Apple Silicon is the only supported" >&2
  echo 'platform (ADR-036), and /usr/local there is an x86_64 Homebrew under' >&2
  echo 'Rosetta, so a fallback selects translated binaries and reports success.' >&2
  echo 'Use brew_prefix, or the "brew-prefix"/"brew-shellenv" templates.' >&2
  exit 1
done < <(
  grep -rl '/usr/local/bin/brew' \
    "$ROOT/script" "$ROOT/chezmoi" "$ROOT/bootstrap" 2>/dev/null || true
)

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

# confirm() fails closed with no terminal on stdin, and its warning is the only guidance
# the caller gets. It used to say "Pass --yes", which just eight of its nine callers do
# not implement: `macos-defaults apply` over ssh printed the advice and then refused
# `--yes` as an unknown argument, so the sudo-scoped defaults could not be applied
# non-interactively at all. The hint must name ASSUME_YES, which every caller honours
# because confirm() itself reads it.
assert_match 'ASSUME_YES=1 to answer yes' "$ROOT/script/lib/common.sh"
refute_match 'Pass --yes to answer' "$ROOT/script/lib/common.sh"

# Anything that both calls confirm() and runs unattended needs the flag to exist too:
# bootstrap is driven by script/test-install and macos-defaults by the chezmoi hook.
# One call per file on purpose: assert_match greps its arguments together and passes on
# the first hit, so naming both files in a single call would prove nothing about the
# second once bootstrap matched.
assert_match '^ *--yes \| -y\)' "$ROOT/bootstrap"
assert_match '^ *--yes \| -y\)' "$ROOT/script/macos-defaults"

# Existing was not enough: the hook has to PASS it.
#
# The flag existed and the hook did not use it, so `macos-defaults apply` from a chezmoi
# apply with no terminal on stdin hit confirm(), failed closed, and wrote NOTHING — not
# just the four sudo-scoped keys, all fifty. It looked correct only because
# `./bootstrap --yes` exports ASSUME_YES=1 and chezmoi's child inherits it; any apply
# that bypassed bootstrap (`ssh host chezmoi apply` without -t, launchd, stdin
# redirected) silently applied no defaults at all while reporting one WARN.
assert_match 'script/macos-defaults" \| quote \}\} apply --yes' \
  "$ROOT/chezmoi/run_onchange_after_40_macos-defaults.sh.tmpl"

# ~/.docker only applies under colima, because every file in it needs a formula that only
# profiles/runtime-colima.Brewfile declares. Ungated, a --runtime rancher or orbstack
# machine got symlinks to /opt/homebrew/opt/docker-compose paths that never exist, written
# over the plugin links Rancher and OrbStack put in that same directory, so `docker
# compose` stopped resolving; and credsStore = osxkeychain without
# docker-credential-helper turned `docker login` into "executable file not found".
assert_match '\.docker' "$ROOT/chezmoi/.chezmoiignore"
assert_match 'ne \.runtime "colima"' "$ROOT/chezmoi/.chezmoiignore"

# The snapshot records the SELECTION, and never the four per-machine keys.
#
# chezmoi.toml lives only on the machine that wrote it, so losing it meant re-answering
# twelve prompts from memory. Copying the file verbatim would be the wrong fix: sourceDir is
# that checkout's absolute path, machineName and ephemeral are detected rather than chosen,
# and with ssh signing the gitSigningKey is generated per machine by design. The replayable
# bootstrap line carries what transfers and omits what must not.
assert_match '== Workstation selection ==' "$ROOT/script/snapshot"
assert_match 'Replay this selection on another Mac' "$ROOT/script/snapshot"
assert_match 'script/snapshot --compare' "$ROOT/script/snapshot"

# Comment lines are skipped, for the third time in this file and the same reason each time:
# the code EXPLAINS that sourceDir must not be recorded, so a plain refute_match matched the
# explanation and failed on the correct file. A check that cannot tell code from prose about
# the code reports the fix as the bug.
snapshot_leaks="$(awk '
  /^[[:space:]]*#/ { next }
  /sourceDir|gitSigningKey/ { printf "  %d: %s\n", FNR, $0 }
' "$ROOT/script/snapshot")"
[[ -z "$snapshot_leaks" ]] || {
  echo 'script/snapshot records a key that must not travel between machines:' >&2
  echo "$snapshot_leaks" >&2
  echo 'sourceDir is this checkout path; an ssh gitSigningKey is generated per machine.' >&2
  exit 1
}

# bootstrap asks for the password once, up front, rather than at three unpredictable moments.
# SECURITY.md and docs/TESTING.md have told the operator to do this by hand all along.
assert_match '^prime_sudo\(\) \{$' "$ROOT/bootstrap"
assert_match '^ *prime_sudo$' "$ROOT/bootstrap"
# NOPASSWD is tested BEFORE `sudo -v`, because `-v` does not honour it. Measured in the
# guest, which has NOPASSWD: ALL — `sudo -n true` exits 0 while `sudo -n -v` reports "a
# password is required", because refreshing the credential timestamp is a password
# operation whatever the command rules say. With the checks the other way round, a
# passwordless machine always fell through to a warning that promised prompts it would
# never see.
assert_match '^ *if sudo -n true 2>/dev/null; then$' "$ROOT/bootstrap"
# No keepalive: suppressing the post-bundle prompt means holding root unattended for the
# 30-45 minutes brew bundle takes, which is a worse trade than one expected prompt.
refute_match 'while true.*sudo -n true|sudo.*keepalive' "$ROOT/bootstrap"

# Documentation must not contradict the code on the two claims that misled a reader most.
#
# README.md and docs/TESTING.md both stated `--runtime none` was the test-install default
# when it is colima — and TESTING.md said both things, 86 lines apart, in the runbook
# followed for a destructive run. ARCHITECTURE.md described macOS defaults as applied "when
# requested" for as long as ADR-041 had made them the default. Neither is the kind of error
# a reader can catch, because both read as authoritative.
# A single-line fragment of the false sentence, with `.` standing in for the backtick.
# The first attempt used `defaults\n?to ...` to span the line break: grep -E has no \n, so
# that pattern could never fire — a refutation that cannot match is not a guard, it is a
# comment that costs a test run.
refute_match 'runtime none. because that suits' "$ROOT/README.md"
refute_match '^.--runtime none. is the default' "$ROOT/docs/TESTING.md"
refute_match 'applies declared macOS defaults when requested' "$ROOT/docs/ARCHITECTURE.md"

# And the skip count, which is the number that decides whether a green local run means
# anything. There are five, not four; the fifth is the atuin config parse.
refute_match 'SKIPS four checks' "$ROOT/AGENTS.md"
refute_match 'four checks skip' "$ROOT/docs/OPERATIONS.md"
refute_match 'Four of those checks skip' "$ROOT/README.md"

# EVERY doc that names the test-install default runtime, not just the two fixed first time.
#
# The F24 sweep corrected README.md and docs/TESTING.md and missed vm/README.md, which went
# on asserting `--runtime none` for another two weeks. Naming the files individually is what
# stops the third one being forgotten again.
# shellcheck disable=SC2016  # backticks are literal markdown here, not a substitution
refute_match 'defaults to .--runtime none.' \
  "$ROOT/README.md" "$ROOT/docs/TESTING.md" "$ROOT/vm/README.md" "$ROOT/docs/OPERATIONS.md"

# The package count README quotes has to track the ceiling, because it is the number a
# reader uses to judge whether an addition is reasonable. It said 68 while the real default
# was 70 — at the ceiling, with no headroom.
assert_match 'install 70 packages with zsh, or 69 with fish' "$ROOT/README.md"

# CI is not Linux-only: validate.yml has a macos-latest job that also runs ./bootstrap plan.
refute_match 'CI remains Linux-only' "$ROOT/README.md"

# security-extra installs no hardware-key tooling — ykman, age-plugin-yubikey and Secretive
# are all commented out, so a doc promising them sends someone to the wrong profile.
# shellcheck disable=SC2016  # backticks are literal markdown here, not a substitution
refute_match 'security-extra. provides .age-plugin-yubikey' "$ROOT/docs/MANUAL-SECURITY.md"

# The apply-hook flow in ARCHITECTURE.md must name every hook. It listed five of ten, and
# the missing one whose absence mattered most was 12, whose position is load-bearing.
for hook_number in 10 12 15 20 25 30 35 40 45 90; do
  assert_match "_${hook_number} " "$ROOT/docs/ARCHITECTURE.md"
done

# neovim is $EDITOR in both shells and core.editor in git, so it must not be unconfigured.
#
# It was, for the entire life of the repository: every commit message, `git rebase -i`, and
# quick fix over ssh opened a bare editor with no clipboard integration on a machine whose
# shell config argues about keymaps.
assert_match '^opt\.clipboard = "unnamedplus"$' "$ROOT/chezmoi/dot_config/nvim/init.lua"

# And it must stay plugin-free. ADR-031 rejects fetching unreviewed code at runtime outside
# the Homebrew trust boundary, and a neovim plugin manager is exactly that.
#
# Comment lines are skipped, because the config explains WHY it has no plugin manager and
# names the tools it is refusing — so a plain refute_match matched that prose and failed on
# the correct file. That is the same false positive tests/chezmoi-templates.sh records for
# its `*fi*` glob and tests/vm.sh for `"$*"`: a check that cannot tell code from the
# explanation of the code reports the fixed state as broken, gets deleted, and then the real
# regression goes unnoticed.
nvim_plugins="$(awk '
  /^[[:space:]]*--/ { next }
  /lazy\.nvim|packer|vim-plug|Plug / { printf "  %d: %s\n", FNR, $0 }
' "$ROOT/chezmoi/dot_config/nvim/init.lua")"
[[ -z "$nvim_plugins" ]] || {
  echo 'nvim/init.lua references a plugin manager:' >&2
  echo "$nvim_plugins" >&2
  echo 'ADR-031: no runtime fetching of unreviewed code.' >&2
  exit 1
}

# Machine identity is recorded by BOTH config writers, or per-machine templates silently
# see an empty value depending on which path created the config. bootstrap writes it on the
# normal install; .chezmoi.toml.tmpl on a direct `chezmoi init`.
#
# scutil, never `hostname`: on macOS `hostname` follows the network and changes with the
# Wi-Fi, which makes it useless as a stable key for per-machine configuration.
assert_match '^machineName = ' "$ROOT/chezmoi/.chezmoi.toml.tmpl"
assert_match '^ephemeral = ' "$ROOT/chezmoi/.chezmoi.toml.tmpl"
assert_match 'machineName = \$\(toml_quote' "$ROOT/bootstrap"
assert_match 'ephemeral = \$\(is_ephemeral\)' "$ROOT/bootstrap"
assert_match 'scutil --get ComputerName' "$ROOT/bootstrap"
refute_match 'output "hostname"' "$ROOT/chezmoi/.chezmoi.toml.tmpl"

# The age identity is RESTORED before it is minted, and the two halves of identity are
# treated differently on purpose.
#
# age files encrypted to a lost identity are unrecoverable, so a new Mac that quietly mints
# a second identity has destroyed access to every existing secret — the old hook did exactly
# that, and printed "back this key up now" at the point it was already too late for the
# previous machine. SSH is the opposite: a signing key is simply re-enrolled, so generating
# per machine is strictly better than moving one around.
assert_match 'bw get notes' "$ROOT/chezmoi/run_once_after_15_bootstrap-age-key.sh.tmpl"
assert_match 'locally-generated' "$ROOT/chezmoi/run_once_after_15_bootstrap-age-key.sh.tmpl"
assert_match 'bitwarden-cli' "$ROOT/profiles/password-bitwarden.Brewfile"

# The marker must be a FAILURE in the report, not a warning: a key existing only on this
# machine is one disk failure from taking every encrypted file with it.
assert_match 'fail "This age identity was generated locally' "$ROOT/script/identity"
assert_match '^ *--restore) MODE="restore" ;;$' "$ROOT/script/identity"
assert_match 'script/identity" --check' "$ROOT/script/verify"

# SSH keys are generated per machine and stay on it.
#
# Bitwarden's SSH agent was the previous design and is deliberately gone: a key that never
# leaves the machine that made it cannot be exposed by losing a different machine, and the
# agent could not sign commits at all — with gpg.format=ssh and no gpg.ssh.program, git
# shells out to `ssh-keygen`, which reads $SSH_AUTH_SOCK and never parses ~/.ssh/config, so
# IdentityAgent had no effect and every commit failed. Verified by signing a commit with no
# agent present and the key on disk: exit 0.
refute_match 'bitwarden-ssh-agent\.sock' "$ROOT/chezmoi/private_dot_ssh/config.tmpl"
assert_match '^ *IdentityFile ~/\.ssh/id_ed25519$' "$ROOT/chezmoi/private_dot_ssh/config.tmpl"
assert_match 'ssh-keygen -t ed25519' \
  "$ROOT/chezmoi/run_onchange_after_12_ssh-key.sh.tmpl"

# 1Password keeps its agent: there the private keys genuinely live in the agent, and a file
# on disk would be a second competing identity.
assert_match 'IdentityAgent "~/Library/Group Containers' \
  "$ROOT/chezmoi/private_dot_ssh/config.tmpl"

# An existing /etc/pam.d/sudo_local must be preserved before it is replaced. The presence
# check only recognises `auth sufficient pam_tid.so`, so a file using `required`,
# pam_watchid or any other local customisation was overwritten by the stock template with
# no copy kept, and sudo silently stopped behaving as configured.
assert_match 'replaced-by-bootstrap' "$ROOT/bootstrap"

# The age hook renders whether age-keygen exists, which is what makes it retry.
#
# run_once_ is keyed on the script's content hash, so with static content a machine whose
# `brew bundle` failed to install age printed one WARN, was recorded as done, and never
# created the identity — leaving SOPS unusable with nothing reporting it. Rendering the
# tool's presence changes the hash once it is installed, so the next apply re-runs it.
assert_match 'lookPath "age-keygen"' \
  "$ROOT/chezmoi/run_once_after_15_bootstrap-age-key.sh.tmpl"

# git treats user.signingkey as a FILE PATH under gpg.format=ssh, rescuing only keys that
# begin "ssh-". Verified by signing with each form: a raw ecdsa-sha2-nistp256 key exits 128
# with "Couldn't load public key", and key:: works for every type. Without the prefix every
# Secretive key (Secure Enclave is ECDSA-only) and every YubiKey sk- key failed on EVERY
# commit, since commit.gpgsign is true — and both are recommended in that same file.
assert_match 'key::%s' "$ROOT/chezmoi/dot_gitconfig.tmpl"
# shellcheck disable=SC2016  # a literal $ in the search pattern, not an expansion
assert_match 'hasPrefix "ecdsa-" \$signingKey' "$ROOT/chezmoi/dot_gitconfig.tmpl"
# shellcheck disable=SC2016  # a literal $ in the search pattern, not an expansion
assert_match 'hasPrefix "sk-" \$signingKey' "$ROOT/chezmoi/dot_gitconfig.tmpl"

# The macOS defaults and the firewall are on by default, and each needs a way out.
# Asserted rather than commented because the whole point is that forgetting a flag no
# longer silently downgrades the machine — a revert to `=false` must break the suite.
assert_match '^APPLY_MACOS_DEFAULTS=true$' "$ROOT/bootstrap"
assert_match '^WITH_HARDENING=true$' "$ROOT/bootstrap"
assert_match '^ *--no-macos-defaults\)' "$ROOT/bootstrap"
assert_match '^ *--no-hardening\)' "$ROOT/bootstrap"

# test-install must agree with bootstrap, or the harness tests defaults nobody ships.
assert_match '^WITH_MACOS_DEFAULTS=true$' "$ROOT/script/test-install"
assert_match '^WITH_HARDENING=true$' "$ROOT/script/test-install"

# And it must forward the negative explicitly: bootstrap now treats a missing flag as
# "on", so a bare `[[ x == true ]] &&` would turn --no-hardening into a silent no-op.
assert_match 'bootstrap_args\+=\(--no-macos-defaults\)' "$ROOT/script/test-install"
assert_match 'bootstrap_args\+=\(--no-hardening\)' "$ROOT/script/test-install"

echo 'Placement policy: OK'
