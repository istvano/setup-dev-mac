#!/usr/bin/env bash
# Keep the profile catalogue consistent across the four places that declare it.
#
# Profile names and the mutually exclusive alternatives are currently repeated
# in script/lib/profiles.sh, bootstrap, script/render-brewfile and
# chezmoi/.chezmoi.toml.tmpl. A missing fragment used to surface only at render
# time, and only when the affected profile happened to be selected.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=script/lib/profiles.sh
source "$ROOT/script/lib/profiles.sh"

CONFIG_TEMPLATE="$ROOT/chezmoi/.chezmoi.toml.tmpl"

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

# --- Every declared profile has a fragment, and every fragment is declared.

for profile in "${VALID_PROFILES[@]}"; do
  [[ -f "$ROOT/profiles/$profile.Brewfile" ]] ||
    fail "VALID_PROFILES lists '$profile' but profiles/$profile.Brewfile is missing."
  grep -q "\"$profile\"" "$CONFIG_TEMPLATE" ||
    fail "VALID_PROFILES lists '$profile' but .chezmoi.toml.tmpl does not offer it."
done

for fragment in "$ROOT"/profiles/*.Brewfile; do
  name="$(basename "$fragment" .Brewfile)"
  # Alternatives are selected by their own flags, not by the profile list.
  case "$name" in
    shell-* | runtime-* | password-* | firewall-*) continue ;;
  esac
  declared=false
  for profile in "${VALID_PROFILES[@]}"; do
    [[ "$name" == "$profile" ]] && declared=true && break
  done
  [[ "$declared" == true ]] ||
    fail "profiles/$name.Brewfile exists but VALID_PROFILES does not declare it."
done

for profile in ${DEFAULT_PROFILES//,/ }; do
  declared=false
  for valid in "${VALID_PROFILES[@]}"; do
    [[ "$profile" == "$valid" ]] && declared=true && break
  done
  [[ "$declared" == true ]] ||
    fail "DEFAULT_PROFILES contains '$profile', which is not a valid profile."
done

# --- The mutually exclusive alternatives agree everywhere and have fragments.

# Reads the alternation out of a `[[ "$VAR" =~ ^(a|b|none)$ ]]` guard.
extract_choices() {
  local file="$1" variable="$2"
  grep -E "\"\\\$$variable\" =~ " "$file" |
    sed -E 's/.*\^\(([^)]*)\)\$.*/\1/' |
    tr '|' '\n' |
    sort -u
}

check_alternative() {
  local variable="$1" prefix="$2"
  local from_bootstrap from_render choice

  from_bootstrap="$(extract_choices "$ROOT/bootstrap" "$variable")"
  from_render="$(extract_choices "$ROOT/script/render-brewfile" "$variable")"

  [[ -n "$from_bootstrap" ]] || fail "No $variable choices found in bootstrap."
  [[ "$from_bootstrap" == "$from_render" ]] ||
    fail "$variable choices differ between bootstrap and script/render-brewfile."

  while IFS= read -r choice; do
    [[ -n "$choice" && "$choice" != none ]] || continue
    [[ -f "$ROOT/profiles/$prefix-$choice.Brewfile" ]] ||
      fail "$variable offers '$choice' but profiles/$prefix-$choice.Brewfile is missing."
    grep -q "\"$choice\"" "$CONFIG_TEMPLATE" ||
      fail "$variable offers '$choice' but .chezmoi.toml.tmpl does not."
  done <<<"$from_bootstrap"
}

check_alternative SHELL_CHOICE shell
check_alternative RUNTIME runtime
check_alternative PASSWORD_MANAGER password
check_alternative FIREWALL firewall

# The shell is the one alternative with no `none`: a workstation always has an
# interactive shell. So its fragment must be appended unconditionally, and a
# copied `!= none` guard would drop it for every selection at once.
shell_append="$(grep -n 'profiles/shell-' "$ROOT/script/render-brewfile" | head -n 1)"
[[ -n "$shell_append" ]] ||
  fail "script/render-brewfile does not append a shell fragment."
[[ "$shell_append" != *none* ]] ||
  fail "The shell fragment must not be guarded by a none check: $shell_append"

# --- Every script that re-renders the selected Brewfile passes every dimension.
#
# script/update-report shipped without --shell and would have rendered a zsh
# Brewfile on a fish machine, so its cleanup section listed the user's own shell
# as a package to remove — plausible output, wrong answer. The failure is one of
# omission, so it is checked by enumeration rather than by reading each caller.
# Not mapfile; see tests/shell-syntax.sh. macOS bash is 3.2.
#
# No xargs: with empty input its behaviour differs between GNU and BSD, and a
# selector that matched nothing must not become "grep reading stdin".
RENDER_CALLERS=()
while IFS= read -r found; do
  grep -q 'chezmoi data' "$found" || continue
  RENDER_CALLERS+=("$found")
done < <(grep -rl 'render-brewfile' "$ROOT/script" | sort)
((${#RENDER_CALLERS[@]} > 0)) ||
  fail 'No script renders the configured Brewfile; the selector is broken.'
for caller in "${RENDER_CALLERS[@]}"; do
  for flag in --profiles --shell --runtime --password-manager --firewall; do
    grep -q -- "$flag" "$caller" ||
      fail "$(basename "$caller") reads chezmoi data but never passes $flag."
  done
done

echo "Profile catalogue: OK (${#VALID_PROFILES[@]} profiles)"
