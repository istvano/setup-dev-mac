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
