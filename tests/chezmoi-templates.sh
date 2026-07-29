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

mapfile -t TEMPLATES < <(find "$ROOT/chezmoi" -type f -name '*.tmpl' | sort)
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
# fully enabled paid selection.
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

echo "Chezmoi templates: OK (${#TEMPLATES[@]} templates x ${#CONFIGS[@]} configurations)"
