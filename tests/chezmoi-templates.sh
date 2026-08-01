#!/usr/bin/env bash
# Validate the chezmoi templates.
#
# .chezmoiroot points chezmoi at <repo>/chezmoi, so .chezmoi.sourceDir resolves
# to the chezmoi subdirectory, not the repository root. Templates that reached
# back into the repository through .chezmoi.sourceDir produced
# <repo>/chezmoi/script/... and broke package installation, macOS defaults and
# browser-profile provisioning on first apply. Repository paths must therefore
# go through `dir .chezmoi.sourceDir`.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib.sh
source "$ROOT/tests/lib.sh"

# Not mapfile; see tests/shell-syntax.sh. macOS bash is 3.2.
TEMPLATES=()
while IFS= read -r found; do TEMPLATES+=("$found"); done \
  < <(find "$ROOT/chezmoi" -type f -name '*.tmpl' | sort)
((${#TEMPLATES[@]} > 0)) || {
  echo 'No chezmoi templates discovered; the selector is broken.' >&2
  exit 1
}

# --- Static guard: repository paths must not be built from the raw source dir.

for template in "${TEMPLATES[@]}"; do
  while IFS= read -r line; do
    [[ "$line" == *'.chezmoi.sourceDir'* && "$line" == *'script/'* ]] || continue
    if [[ "$line" != *'dir .chezmoi.sourceDir'* ]]; then
      printf '%s: repository path built from .chezmoi.sourceDir without dir.\n' \
        "$template" >&2
      printf '  %s\n' "$line" >&2
      printf '  .chezmoiroot makes .chezmoi.sourceDir the chezmoi/ subdirectory.\n' >&2
      exit 1
    fi
  done <"$template"
done

# --- Dynamic: execute every template and prove the paths it emits exist.

if ! command -v chezmoi >/dev/null 2>&1; then
  if [[ "${REQUIRE_CHEZMOI:-0}" == "1" ]]; then
    echo 'chezmoi is required when REQUIRE_CHEZMOI=1.' >&2
    exit 1
  fi
  echo 'Chezmoi templates: static guard OK; chezmoi not installed, execution skipped'
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Two configurations so both sides of every conditional are executed: the
# default free selection with signing and the work identity disabled, and the
# fully enabled paid selection. The paid one also selects fish, so the fish
# branches of the Ghostty config and .chezmoiignore are executed somewhere.
cat >"$TMP/minimal.toml" <<EOF
sourceDir = "$ROOT"
[data]
gitName = "Test User"
gitEmail = "test@example.invalid"
gitSigningMethod = "none"
gitSigningKey = ""
workGitDir = "~/work"
workGitEmail = ""
profiles = ["core", "security", "productivity"]
shell = "zsh"
runtime = "colima"
passwordManager = "bitwarden"
firewall = "lulu"
applyMacOSDefaults = false
EOF

cat >"$TMP/full.toml" <<EOF
sourceDir = "$ROOT"
[data]
gitName = "Test User"
gitEmail = "test@example.invalid"
gitSigningMethod = "ssh"
gitSigningKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITESTKEYFORVALIDATIONONLY"
workGitDir = "~/work"
workGitEmail = "work@example.invalid"
profiles = ["core", "dev", "security", "security-extra", "productivity", "productivity-extra"]
shell = "fish"
runtime = "rancher"
passwordManager = "1password"
firewall = "little-snitch"
applyMacOSDefaults = true
EOF

# GPG is the default signing method, so it needs its own execution path.
cat >"$TMP/gpg.toml" <<EOF
sourceDir = "$ROOT"
[data]
gitName = "Test User"
gitEmail = "test@example.invalid"
gitSigningMethod = "gpg"
gitSigningKey = "0x0000000000000000"
workGitDir = "~/work"
workGitEmail = "work@example.invalid"
profiles = ["core", "dev", "security", "productivity"]
shell = "zsh"
runtime = "rancher"
passwordManager = "bitwarden"
firewall = "lulu"
applyMacOSDefaults = true
EOF

CONFIGS=("$TMP/minimal.toml" "$TMP/full.toml" "$TMP/gpg.toml")

render() {
  chezmoi execute-template --config "$CONFIG" --source "$ROOT" "$@"
}

for CONFIG in "${CONFIGS[@]}"; do
  for template in "${TEMPLATES[@]}"; do
    # The config template uses the prompt*Once functions, which only exist
    # during initialisation. The values above are already present in the
    # config, so the Once variants read them back instead of prompting.
    init_flags=()
    [[ "$(basename "$template")" == ".chezmoi.toml.tmpl" ]] && init_flags=(--init)

    # Executes on this platform. Go parses the whole template regardless of
    # which branch runs, so undefined functions surface here even for
    # darwin-only code.
    render "${init_flags[@]+"${init_flags[@]}"}" <"$template" >/dev/null

    # Force the darwin branch so macOS-only bodies are actually evaluated on
    # Linux CI. Without this the guarded bodies are parsed but never executed,
    # and a wrong path inside them cannot be detected away from a Mac.
    rendered="$(sed 's/eq \.chezmoi\.os "darwin"/true/g' "$template" |
      render "${init_flags[@]+"${init_flags[@]}"}")"

    # Every repository script path the template emits must exist and be runnable.
    while IFS= read -r path; do
      [[ -x "$path" ]] || {
        printf '%s: emits a non-executable repository path: %s\n' "$template" "$path" >&2
        exit 1
      }
    done < <(grep -oE '/[^"'"'"' ]*/script/[a-z-]+' <<<"$rendered" | sort -u)
  done
done

# --- No apply hook may abort the ones after it.
#
# chezmoi runs scripts in order and stops at the first non-zero exit, so a hook
# that fails takes every later hook with it. Seen three times on real hardware:
# brew bundle failing cost every dotfile; rdctl returning 500 cost the VS Code
# extensions, the macOS defaults, the browser profiles and the reminder.
#
# These hooks CONFIGURE things. Failing to configure one is worth reporting, not
# worth abandoning the rest of the configuration — ./script/verify and
# script/macos-defaults --verify are what report the resulting drift.
#
# Matched on the last executable line, which is the one whose status chezmoi sees.
for hook in "$ROOT"/chezmoi/run_*_after_*.sh.tmpl; do
  name="$(basename "$hook")"
  # 30 reports and 90 prints a reminder; both end in a plain command that cannot
  # meaningfully fail, and 15 exits 0 on every branch.
  case "$name" in
    *_30_* | *_90_* | *_15_*) continue ;;
  esac
  last="$(grep -vE '^\s*#|^\s*$|^\{\{-? ?end \}\}$' "$hook" | tail -n 1)"
  # Anchored regexes, not globs. `*fi*` matched "browser-profile" and passed a
  # genuinely unguarded hook — the test looked like it worked and did not.
  if [[ "$last" =~ \|\|[[:space:]]*echo ]] ||
    [[ "$last" =~ ^[[:space:]]*fi$ ]] ||
    [[ "$last" =~ ^[[:space:]]*exit[[:space:]]+0$ ]] ||
    [[ "$last" =~ \>\&2$ ]]; then
    continue
  fi
  echo "$name ends in an unguarded command:" >&2
  echo "  $last" >&2
  echo 'A non-zero exit here aborts every later apply hook. Report the' >&2
  echo 'failure and continue instead.' >&2
  exit 1
done

# --- A failed package install must not abort the whole apply.
#
# run_onchange_before_10 runs BEFORE any file is written, so a non-zero exit
# takes the dotfiles, the macOS defaults and the browser profiles down with it.
# Observed for real: nine formulae had no bottle on macOS 13, brew bundle exited
# non-zero, and the machine ended up with 195 packages and zero configuration.
packages_hook="$ROOT/chezmoi/run_onchange_before_10_install-packages.sh.tmpl"
if grep -qE '^brew bundle check .*\|\| brew bundle install' "$packages_hook"; then
  echo 'run_onchange_before_10 lets brew bundle fail the apply.' >&2
  echo 'It is a run_before hook, so that costs every dotfile, not just packages.' >&2
  echo 'Report the failure and continue; ./script/verify still catches the drift.' >&2
  exit 1
fi
assert_match 'The apply continues so' "$packages_hook"

# --- The chezmoi diff configuration must not set diff.command.
#
# Setting it makes chezmoi invoke the tool per FILE, and delta opens a pager each
# time, so reviewing a multi-file apply meant quitting one pager after another
# with no way to see the whole thing. `diff.pager` alone pipes one unified diff
# through delta, which is what --no-pager can also disable. Both writers of this
# config are checked, since bootstrap writes it too.
for config_writer in "$ROOT/chezmoi/.chezmoi.toml.tmpl" "$ROOT/bootstrap"; do
  if grep -qE '^command = "delta"' "$config_writer"; then
    echo "$(basename "$config_writer") sets diff.command = delta." >&2
    echo "That runs delta per file and opens a pager for each one. Use only" >&2
    echo "diff.pager, which pipes a single unified diff through delta." >&2
    exit 1
  fi
done

# --- .chezmoiignore is a template too, but has no .tmpl suffix.
#
# The selector above finds files by extension, so this file is invisible to it.
# It decides whether a whole configuration directory reaches the machine, and a
# broken conditional here fails open — the target is simply not ignored — so it
# needs its own execution.
IGNORE="$ROOT/chezmoi/.chezmoiignore"
[[ -f "$IGNORE" ]] || {
  echo 'chezmoi/.chezmoiignore is missing; the shell conditional is not enforced.' >&2
  exit 1
}
# Asserted through `chezmoi managed` rather than by reading the rendered text.
# Whether a pattern actually excludes a directory is chezmoi's decision, not
# something a grep for ".config/fish" can establish — the same reason ADR-030
# prefers `ghostty +show-config` over reading the config file. This needs a
# destDir, so each configuration gets a throwaway one.
for CONFIG in "${CONFIGS[@]}"; do
  selected="$(grep -E '^shell = ' "$CONFIG" | sed -E 's/.*"(.*)".*/\1/')"
  dest="$TMP/dest-$(basename "$CONFIG" .toml)"
  mkdir -p "$dest"
  # The suffix must stay .toml: chezmoi infers the config format from the file
  # extension, so a name like minimal.toml.scoped is rejected outright.
  scoped="${CONFIG%.toml}.scoped.toml"
  # destDir is a top-level key, so it must precede the [data] table.
  {
    printf 'destDir = "%s"\n' "$dest"
    cat "$CONFIG"
  } >"$scoped"

  managed="$(chezmoi managed --config "$scoped" --source "$ROOT" 2>/dev/null)"

  # `if`, not `x && y=true`: a failing grep makes the whole list non-zero and
  # errexit exits the script, turning a passing assertion into a silent stop.
  if grep -qx '.config/fish/config.fish' <<<"$managed"; then
    fish_managed=true
  else
    fish_managed=false
  fi

  if [[ "$selected" == fish && "$fish_managed" == false ]]; then
    echo "shell=fish but chezmoi does not manage .config/fish/config.fish." >&2
    printf 'managed:\n%s\n' "$managed" >&2
    exit 1
  fi
  if [[ "$selected" != fish && "$fish_managed" == true ]]; then
    echo "shell=$selected but chezmoi still manages .config/fish/config.fish;" >&2
    echo ".chezmoiignore is not excluding it." >&2
    exit 1
  fi

  # .zshrc is never ignored: zsh stays the login shell even when fish is the
  # selected interactive shell (ADR-031), so its configuration must keep working.
  grep -qx '.zshrc' <<<"$managed" || {
    echo "shell=$selected: .zshrc must always be managed." >&2
    exit 1
  }

  # The Ghostty command line must render to a real absolute path.
  #
  # It is the one place the Homebrew prefix cannot be discovered at runtime — a
  # terminal config is a static string, not a shell — so it is resolved at apply
  # time. A broken template would leave `command = /bin/fish --login`, which is a
  # path that exists on macOS and is the wrong shell entirely.
  if [[ "$selected" == fish ]]; then
    ghostty_command="$(render <"$ROOT/chezmoi/dot_config/ghostty/config.tmpl" |
      grep '^command = ' || true)"
    [[ "$ghostty_command" =~ ^command\ =\ (/opt/homebrew|/usr/local)/bin/fish\ --login$ ]] || {
      echo "ghostty config.tmpl rendered an unexpected command line:" >&2
      echo "  ${ghostty_command:-<none>}" >&2
      echo "Expected a Homebrew prefix followed by /bin/fish --login." >&2
      exit 1
    }
  fi

  # Every managed file or directory must be a dotfile.
  #
  # chezmoi treats every file under its source directory as a target, so
  # chezmoi/AGENTS.md — documentation for whoever edits the source state — was
  # being written to ~/AGENTS.md on every apply. Nothing failed and nothing
  # complained; the home directory just quietly gained a file from the repository.
  # Scripts are excluded because run_ entries are actions, not targets.
  stray="$(chezmoi managed --include=files,dirs --config "$scoped" \
    --source "$ROOT" 2>/dev/null | grep -v '^\.' || true)"
  [[ -z "$stray" ]] || {
    echo "shell=$selected: these managed targets are not dotfiles, so they would" >&2
    echo "be written into the home directory. Add them to chezmoi/.chezmoiignore:" >&2
    printf '  %s\n' "$stray" >&2
    exit 1
  }
done

echo "Chezmoi templates: OK (${#TEMPLATES[@]} templates x ${#CONFIGS[@]} configurations)"
