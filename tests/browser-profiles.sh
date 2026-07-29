#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export BROWSER_PROFILE_ROOT="$TMP/browser-profiles"

"$ROOT/script/browser-profile" ensure-defaults >/dev/null
for browser in chrome firefox; do
  for profile in personal work; do
    path="$BROWSER_PROFILE_ROOT/$browser/$profile"
    [[ -d "$path" ]]
    if stat -f '%Lp' "$path" >/dev/null 2>&1; then
      mode="$(stat -f '%Lp' "$path")"
    else
      mode="$(stat -c '%a' "$path")"
    fi
    [[ "$mode" == 700 ]]
  done
done

"$ROOT/script/browser-profile" add cloud-admin >/dev/null
list="$("$ROOT/script/browser-profile" list)"
grep -q '^chrome[[:space:]]*personal$' <<<"$list"
grep -q '^firefox[[:space:]]*work$' <<<"$list"
grep -q '^chrome[[:space:]]*cloud-admin$' <<<"$list"
grep -q '^firefox[[:space:]]*cloud-admin$' <<<"$list"

"$ROOT/script/browser-profile" ensure-defaults >/dev/null
if "$ROOT/script/browser-profile" add '../escape' >/dev/null 2>&1; then
  echo 'Unsafe browser profile name was unexpectedly accepted.' >&2
  exit 1
fi
ln -s "$TMP" "$BROWSER_PROFILE_ROOT/chrome/linked"
if "$ROOT/script/browser-profile" add linked >/dev/null 2>&1; then
  echo 'Symlinked browser profile path was unexpectedly accepted.' >&2
  exit 1
fi

# Provisioning must fire for every profile that can install a browser. The
# required set is derived from profiles/ rather than hardcoded, so moving a
# browser cask between profiles cannot leave it installed without its isolated
# data roots and without the browser-profile command.
gate="$ROOT/chezmoi/run_onchange_after_45_configure-browser-profiles.sh.tmpl"
browser_profiles=0
for fragment in "$ROOT"/profiles/*.Brewfile; do
  grep -qE '^[[:space:]]*cask "(google-chrome|firefox@developer-edition)"' "$fragment" || continue
  name="$(basename "$fragment" .Brewfile)"
  browser_profiles=$((browser_profiles + 1))
  grep -q "has \"$name\" .profiles" "$gate" || {
    echo "profiles/$name.Brewfile declares a browser but is not in the provisioning gate." >&2
    exit 1
  }
done
((browser_profiles > 0)) || {
  echo 'No profile declares a browser cask; the detection is broken.' >&2
  exit 1
}
echo 'Browser profile management: OK'
