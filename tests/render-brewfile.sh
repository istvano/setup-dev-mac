#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib.sh
source "$ROOT/tests/lib.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# shellcheck source=script/lib/profiles.sh
source "$ROOT/script/lib/profiles.sh"
"$ROOT/script/render-brewfile" --output "$TMP/Brewfile"
python3 - "$TMP/Brewfile" "$ROOT"/profiles/*.Brewfile <<'PY'
from pathlib import Path
import re
import sys

entry = re.compile(
    r'^(?:brew|cask) "[A-Za-z0-9][A-Za-z0-9+@._/-]*"[ \t]+#[ \t]+\S.*$'
)
for filename in sys.argv[1:]:
    for number, line in enumerate(Path(filename).read_text().splitlines(), 1):
        if not line or line.startswith("#") or entry.fullmatch(line):
            continue
        raise SystemExit(
            f"{filename}:{number}: dependency needs a purpose comment: {line}"
        )
PY
grep -q 'cask "betterdisplay"' "$TMP/Brewfile"
grep -q 'brew "btop"' "$TMP/Brewfile"
grep -q 'cask "zed"' "$TMP/Brewfile"
grep -q 'cask "rancher"' "$TMP/Brewfile"
grep -q 'cask "bitwarden"' "$TMP/Brewfile"
grep -q 'cask "lulu"' "$TMP/Brewfile"
refute_match 'cask "1password"' "$TMP/Brewfile"

# One tool per job (ADR-022). Each duplicate below has a replacement that must
# still be present, so a regression cannot quietly remove capability instead.
grep -q 'brew "eza"' "$TMP/Brewfile"       # replaces tree, via --tree
grep -q 'brew "git-delta"' "$TMP/Brewfile" # replaces difftastic
refute_match '^brew "(htop|tree|difftastic|wget)"' "$TMP/Brewfile"

# Language runtimes come from mise, not Homebrew (ADR-021).
refute_match '^brew "(rustup|pnpm)"' "$TMP/Brewfile"

# Security tooling is opt-in; the default keeps the general crypto toolkit, plus
# sops, which pairs with the age identity every apply creates.
grep -q 'brew "openssl@3"' "$TMP/Brewfile"
refute_match '^brew "(nmap|cosign|step)"' "$TMP/Brewfile"

# Local inference is opt-in only (ADR-025).
refute_match '^cask "lm-studio"' "$TMP/Brewfile"

# Lab virtualisation, authoring and cluster tooling are opt-in (ADR-027).
refute_match '^(brew|cask) "(lima|utm|ansible|d2|pandoc|drawio|argocd|kustomize|mcp-inspector)"' "$TMP/Brewfile"

# Backup is part of the default selection: the tooling ships, nothing is scheduled.
grep -q 'brew "restic"' "$TMP/Brewfile"
grep -q 'brew "rclone"' "$TMP/Brewfile"

# sops lives with age in core, because the age identity is created on every apply.
grep -q 'brew "sops"' "$TMP/Brewfile"
grep -q 'brew "xh"' "$TMP/Brewfile"
refute_match '^(brew|cask) "(bun|httpie|mas|procs|rectangle|wireguard-tools)"' "$TMP/Brewfile"
refute_match '^(brew|cask) "(awscli|azure-cli|burp-suite|dbeaver-community|gcloud-cli|kubernetes-cli)"' "$TMP/Brewfile"

# A deliberate ceiling on the default trusted computing base (ADR-013). Raising
# it is a reviewed decision, not routine maintenance: every entry is software
# that runs on the host by default.
default_count="$(grep -E -c '^(brew|cask) "' "$TMP/Brewfile")"
((default_count <= 50)) || {
  echo "Default Brewfile exceeds 50 entries: $default_count" >&2
  exit 1
}

"$ROOT/script/render-brewfile" \
  --profiles core,dev,security,security-extra,security-scan,backup,local-llm,lab,docs,mcp,cloud,cloud-aws,cloud-azure,cloud-gcp,kubernetes,data,productivity,productivity-extra,paid \
  --runtime orbstack \
  --password-manager 1password \
  --firewall little-snitch \
  --output "$TMP/optional.Brewfile" >/dev/null
grep -q 'brew "awscli"' "$TMP/optional.Brewfile"
grep -q 'brew "azure-cli"' "$TMP/optional.Brewfile"
grep -q 'cask "gcloud-cli"' "$TMP/optional.Brewfile"
grep -q 'brew "kubernetes-cli"' "$TMP/optional.Brewfile"
grep -q 'cask "burp-suite"' "$TMP/optional.Brewfile"
grep -q 'cask "dbeaver-community"' "$TMP/optional.Brewfile"
grep -q 'cask "obsidian"' "$TMP/optional.Brewfile"
grep -q 'cask "orbstack"' "$TMP/optional.Brewfile"
grep -q 'cask "1password"' "$TMP/optional.Brewfile"
grep -q 'cask "little-snitch"' "$TMP/optional.Brewfile"
grep -q 'brew "restic"' "$TMP/optional.Brewfile"
grep -q 'brew "trivy"' "$TMP/optional.Brewfile"
grep -q 'brew "granted"' "$TMP/optional.Brewfile"
grep -q 'brew "nmap"' "$TMP/optional.Brewfile"
grep -q 'brew "sops"' "$TMP/optional.Brewfile"
grep -q 'brew "cosign"' "$TMP/optional.Brewfile"
grep -q 'cask "lm-studio"' "$TMP/optional.Brewfile"
grep -q 'brew "lima"' "$TMP/optional.Brewfile"
grep -q 'cask "utm"' "$TMP/optional.Brewfile"
grep -q 'brew "ansible"' "$TMP/optional.Brewfile"
grep -q 'brew "d2"' "$TMP/optional.Brewfile"
grep -q 'brew "argocd"' "$TMP/optional.Brewfile"
grep -q 'brew "mcp-inspector"' "$TMP/optional.Brewfile"

refute_command 'Duplicate profiles were unexpectedly accepted.' \
  "$ROOT/script/render-brewfile" --profiles core,core --output "$TMP/duplicate.Brewfile"

[[ "$DEFAULT_PROFILES" == "core,dev,security,productivity,backup" ]]
grep -q '(list "core" "dev" "security" "productivity" "backup")' "$ROOT/chezmoi/.chezmoi.toml.tmpl"
for profile in "${VALID_PROFILES[@]}"; do
  grep -q "\"$profile\"" "$ROOT/chezmoi/.chezmoi.toml.tmpl"
done
echo 'Brewfile rendering and policy: OK'
