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
# Colima is the default runtime (ADR-037), so the default selection carries its
# CLI stack and NOT the Rancher Desktop cask. Both directions are asserted: shipping
# both would install a second Docker client, and two runtimes competing for the
# Docker socket is a correctness problem before it is a performance one.
grep -q 'brew "colima"' "$TMP/Brewfile"
grep -q 'brew "docker"' "$TMP/Brewfile"
grep -q 'brew "docker-compose"' "$TMP/Brewfile"
grep -q 'brew "docker-buildx"' "$TMP/Brewfile"
refute_match '^cask "rancher"' "$TMP/Brewfile"
grep -q 'cask "bitwarden"' "$TMP/Brewfile"
grep -q 'cask "lulu"' "$TMP/Brewfile"
refute_match 'cask "1password"' "$TMP/Brewfile"

# The default shell is zsh, so its two plugin formulae ship and fish does not.
grep -q 'brew "zsh-autosuggestions"' "$TMP/Brewfile"
grep -q 'brew "zsh-syntax-highlighting"' "$TMP/Brewfile"
refute_match '^brew "fish"' "$TMP/Brewfile"

# One tool per job (ADR-022). Each duplicate below has a replacement that must
# still be present, so a regression cannot quietly remove capability instead.
grep -q 'brew "eza"' "$TMP/Brewfile"       # replaces tree, via --tree
grep -q 'brew "git-delta"' "$TMP/Brewfile" # replaces difftastic
refute_match '^brew "(htop|tree|difftastic|wget)"' "$TMP/Brewfile"

# Language runtimes come from mise, not Homebrew (ADR-021).
#
# The JVM entries were added when mise took over the whole JVM ecosystem rather than just
# the JDK. Two managers deciding one version is the precise failure ADR-021 exists to
# prevent: `mvn` on PATH from Homebrew while mise pins 3.9 in the project means the build
# runs under whichever won the PATH race, and nothing reports the disagreement.
refute_match '^brew "(rustup|pnpm|maven|gradle|kotlin|openjdk|openjdk@[0-9]+|sdkman-cli)"' \
  "$TMP/Brewfile"

# Security tooling is opt-in; the default keeps the general crypto toolkit, plus
# sops, which pairs with the age identity every apply creates.
grep -q 'brew "openssl@3"' "$TMP/Brewfile"
refute_match '^brew "(nmap|cosign|step)"' "$TMP/Brewfile"

# Local inference is opt-in only (ADR-025).
refute_match '^cask "lm-studio"' "$TMP/Brewfile"

# Lab virtualisation, authoring and MCP tooling stay opt-in (ADR-027).
#
# argocd and kustomize left this list when kubernetes joined the default set
# (ADR-038): they live in profiles/kubernetes.Brewfile, so refuting them here would
# assert the opposite of what the default now installs.
refute_match '^(brew|cask) "(lima|utm|ansible|d2|pandoc|drawio|mcp-inspector)"' "$TMP/Brewfile"

# Backup is part of the default selection: the tooling ships, nothing is scheduled.
grep -q 'brew "restic"' "$TMP/Brewfile"
grep -q 'brew "rclone"' "$TMP/Brewfile"

# sops lives with age in core, because the age identity is created on every apply.
grep -q 'brew "sops"' "$TMP/Brewfile"
grep -q 'brew "xh"' "$TMP/Brewfile"
refute_match '^(brew|cask) "(bun|httpie|mas|procs|rectangle|wireguard-tools)"' "$TMP/Brewfile"
refute_match '^(brew|cask) "(awscli|azure-cli|burp-suite|dbeaver-community|gcloud-cli)"' "$TMP/Brewfile"

# Kubernetes is part of the DEFAULT selection (ADR-038), so this is asserted rather
# than refuted. It moved because the workstation's purpose is Docker, Kubernetes and
# AI development — k8s was never specialist here, and treating it as opt-in meant the
# default install could not do the job the machine exists for.
grep -q 'brew "kubernetes-cli"' "$TMP/Brewfile"
grep -q 'brew "helm"' "$TMP/Brewfile"
grep -q 'brew "k3d"' "$TMP/Brewfile"
grep -q 'brew "k9s"' "$TMP/Brewfile"

# Authoring containers is the default purpose, so linting a Dockerfile and scanning an
# image are default tools (ADR-040). Both directions are asserted, because the point of
# the change was that these two moved and the other five deliberately did not.
grep -q 'brew "hadolint"' "$TMP/Brewfile"
grep -q 'brew "trivy"' "$TMP/Brewfile"

# The rest of security-scan stays opt-in under ADR-022: grype re-scans what trivy
# scans, osv-scanner duplicates its dependency checking, trufflehog duplicates the
# gitleaks already in core, and syft and dive are release and debugging tools rather
# than daily ones. Refuted so the next "while we are here" addition has to argue.
refute_match '^brew "(grype|osv-scanner|trufflehog|syft|dive)"' "$TMP/Brewfile"

# A deliberate ceiling on the default trusted computing base (ADR-013). Raising
# it is a reviewed decision, not routine maintenance: every entry is software
# that runs on the host by default.
#
# Raised to 70 by ADR-038, which added the kubernetes profile to the default set: 13
# entries for kubectl, helm, k3d, k9s and the rest. That is a real growth of the
# default trusted computing base, from 51 to 64, and it was a reviewed decision rather
# than drift — the machine exists for Docker and Kubernetes development, so a default
# that cannot do Kubernetes is not a smaller default, it is an incomplete one.
#
# The default is now 70 — the ceiling exactly, with no headroom left. Two entries were
# added after that raise, each for a reason recorded where it lives:
#
#   bitwarden-cli  the age identity is restored from the vault on a new machine, and the
#                  desktop app cannot be scripted. Without it the only path is minting a
#                  fresh identity, which makes existing SOPS files unreadable.
#   obsidian       moved out of productivity-extra so a new Mac has it on day one.
#
# So the NEXT addition fails this test, and that is the mechanism working rather than an
# obstacle to route around. Raising the number again is an ADR, and the argument has to be
# about what belongs on the host by default — not about making room.
#
# Previously raised from 50 to 55 by ADR-037, and worth recording WHY, because that
# number moved in the opposite direction to the thing it is a proxy for.
#
# Replacing Rancher Desktop with Colima traded one cask for four formulae — colima,
# docker, docker-compose, docker-buildx — so the count rose by three. What was
# actually installed fell: no Electron desktop application, no bundled Kubernetes
# control plane, no privileged background daemon, no GUI updater. A cask that
# installs an entire desktop runtime counts as one entry and a single-purpose CLI
# binary also counts as one, so entry count measures declarations, not surface.
#
# The ceiling still earns its place as a brake on casual additions. It just cannot be
# read as a security metric on its own.
default_count="$(grep -E -c '^(brew|cask) "' "$TMP/Brewfile")"
((default_count <= 70)) || {
  echo "Default Brewfile exceeds 70 entries: $default_count" >&2
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

# Selecting fish must REPLACE the zsh plugins rather than add to them. Shipping
# both is the failure that matters: it would install a shell nobody selected, or
# leave plugins for a shell that is no longer used, and either still works.
"$ROOT/script/render-brewfile" --shell fish --output "$TMP/fish.Brewfile" >/dev/null
grep -q '^brew "fish"' "$TMP/fish.Brewfile"
refute_match '^brew "zsh-(autosuggestions|syntax-highlighting)"' "$TMP/fish.Brewfile"
# fish provides suggestions and highlighting itself, so it needs no plugin
# manager; fisher and oh-my-fish fetch unreviewed code at runtime (ADR-031).
refute_match '^(brew|cask) "(fisher|oh-my-fish|fishtape|tide)"' "$ROOT/profiles"
# Everything shell-agnostic must survive the switch, or the fragment split moved
# more than it was meant to.
grep -q 'brew "starship"' "$TMP/fish.Brewfile"
grep -q 'brew "atuin"' "$TMP/fish.Brewfile"
grep -q 'cask "ghostty"' "$TMP/fish.Brewfile"

refute_command 'An invalid shell was unexpectedly accepted.' \
  "$ROOT/script/render-brewfile" --shell bash --output "$TMP/bash.Brewfile"

refute_command 'Duplicate profiles were unexpectedly accepted.' \
  "$ROOT/script/render-brewfile" --profiles core,core --output "$TMP/duplicate.Brewfile"

# The default set is declared twice — the shell catalogue and the chezmoi prompt — so
# both are pinned here. kubernetes joined it in ADR-038.
[[ "$DEFAULT_PROFILES" == "core,dev,security,productivity,backup,kubernetes" ]]
grep -q '(list "core" "dev" "security" "productivity" "backup" "kubernetes")' \
  "$ROOT/chezmoi/.chezmoi.toml.tmpl"
for profile in "${VALID_PROFILES[@]}"; do
  grep -q "\"$profile\"" "$ROOT/chezmoi/.chezmoi.toml.tmpl"
done
# docs/TOOLS.md is generated from these same purpose comments, so adding a package
# without regenerating it makes the documentation wrong. Checked here rather than
# trusted, which is the only thing that stops a generated file becoming a stale one.
"$ROOT/script/tools" --check >/dev/null || {
  echo 'docs/TOOLS.md is out of date; regenerate with ./script/tools --write' >&2
  exit 1
}

echo 'Brewfile rendering and policy: OK'
