#!/usr/bin/env bash
# Rosetta is optional, installed only when the operator runs script/install-rosetta
# (ADR-054). AGENTS.md and ADR-012 forbid installing it automatically, and the checks
# below are what hold "optional" apart from "automatic".
#
# Static only: installing Rosetta is a licence prompt and a system change, and Linux CI
# cannot do either.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib.sh
source "$ROOT/tests/lib.sh"

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

INSTALLER="$ROOT/script/install-rosetta"
[[ -x "$INSTALLER" ]] || fail "$INSTALLER is missing or not executable."

# Code lines only. The installer's header explains why it never passes
# --agree-to-license, so matching the whole file would fail on the very comment that
# keeps the rule — the trap tests/vm.sh records for the same flag.
code_lines() {
  awk '/^[[:space:]]*#/ { next } { print }' "$1"
}
CODE="$(mktemp)"
trap 'rm -f "$CODE"' EXIT
code_lines "$INSTALLER" >"$CODE"

# The installer invokes softwareupdate, without the flag whose only purpose is an
# unattended install.
assert_match 'softwareupdate --install-rosetta' "$CODE"
refute_match 'agree-to-license' "$CODE"

# It refuses without a terminal, so no pipeline, CI step or editor task can start it
# and leave Apple's licence prompt waiting.
assert_match '\[\[ -t 0 \]\]' "$CODE"

# It verifies that translation works rather than trusting softwareupdate's exit status,
# using the shared definition rather than a second one that could disagree.
assert_match 'rosetta_available' "$CODE"
assert_match '^rosetta_available\(\) \{' "$ROOT/script/lib/common.sh"
refute_match '^rosetta_available\(\) \{' "$ROOT/script/container-substrate"

# Nothing runs it for you. The install path and every apply hook must not mention it,
# not even in a comment: a mention there is one edit away from an invocation.
for automated in "$ROOT/bootstrap" "$ROOT/script/setup" "$ROOT/script/test-install" \
  "$ROOT/chezmoi"; do
  refute_match 'install-rosetta' "$automated"
done

# And no other script installs Rosetta by calling softwareupdate itself. Comments are
# skipped so that error messages and explanations can still name the command.
others="$(
  grep -R -l -E 'softwareupdate[^#]*--install-rosetta' "$ROOT/script" "$ROOT/bootstrap" |
    grep -v -x -F "$INSTALLER" || true
)"
for file in $others; do
  if code_lines "$file" | grep -q -E 'softwareupdate[^#]*--install-rosetta'; then
    fail "$file installs Rosetta itself; only script/install-rosetta may (ADR-054)."
  fi
done

echo 'Rosetta: OK'
