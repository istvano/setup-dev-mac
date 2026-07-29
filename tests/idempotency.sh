#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/Brewfile"
"$ROOT/script/render-brewfile" --output "$OUT" >/dev/null
FIRST="$(shasum -a 256 "$OUT" | awk '{print $1}')"
"$ROOT/script/render-brewfile" --output "$OUT" >/dev/null
SECOND="$(shasum -a 256 "$OUT" | awk '{print $1}')"
[[ "$FIRST" == "$SECOND" ]]
DIGEST_FIRST="$("$ROOT/script/profile-digest")"
DIGEST_SECOND="$("$ROOT/script/profile-digest")"
[[ "$DIGEST_FIRST" == "$DIGEST_SECOND" ]]
echo 'Render idempotency: OK'
