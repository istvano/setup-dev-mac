#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
"$ROOT/script/render-brewfile" --output "$TMP/Brewfile"
ruby -c "$TMP/Brewfile"
grep -q 'cask "betterdisplay"' "$TMP/Brewfile"
grep -q 'cask "rancher"' "$TMP/Brewfile"
grep -q 'cask "bitwarden"' "$TMP/Brewfile"
grep -q 'cask "lulu"' "$TMP/Brewfile"
! grep -q 'cask "1password"' "$TMP/Brewfile"
echo 'Brewfile rendering: OK'
