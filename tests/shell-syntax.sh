#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Discovery is centralised in script/shell-files so this check, tests/format.sh
# and CI can never drift into linting different sets of files. The previous
# selector matched only *.sh and bootstrap, silently skipping every
# extensionless script under script/.
# Not mapfile: macOS ships bash 3.2.57 as /bin/bash and mapfile is bash 4.0+.
# tests/shell-syntax.sh rejects bash 4 builtins for this reason.
FILES=()
while IFS= read -r file; do FILES+=("$file"); done \
  < <("$ROOT/script/shell-files")

for file in "${FILES[@]}"; do
  bash -n "$file"
done

# --- Reject builtins that macOS's bash does not have.
#
# The target platform ships bash 3.2.57 as /bin/bash, frozen there since Apple
# moved to zsh rather than ship GPLv3. Nothing in this repository installs a newer
# bash, so `#!/usr/bin/env bash` resolves to 3.2 on the one machine that matters.
#
# Linux CI runs bash 5 and cannot see this. `bash -n` cannot either: a missing
# builtin is a runtime lookup failure, not a syntax error, so `mapfile` parses
# cleanly and then fails with "command not found" mid-run. Four test scripts
# already used mapfile and would all have died on first use on the Mac.
#
# Matched in command position only — the name at the start of a statement. That
# keeps this check from flagging the words where they appear inside its own
# pattern and error message, and it is where these builtins are actually called.
# The cost is that `x=1; mapfile ...` on one line would slip through; that shape
# does not occur here and is not worth a shell parser to catch.
BASH4_COMMANDS='^[[:space:]]*(mapfile|readarray)[[:space:]]|^[[:space:]]*(declare|local)[[:space:]]+-[An]'
bash4_found=0
for file in "${FILES[@]}"; do
  if grep -nE "$BASH4_COMMANDS" "$file" >/dev/null; then
    printf '%s: uses a bash 4 builtin; macOS ships bash 3.2.\n' "$file" >&2
    grep -nE "$BASH4_COMMANDS" "$file" >&2
    bash4_found=1
  fi
done
((bash4_found == 0)) || {
  printf 'Read lines with a while/read loop; there is no bash 3.2 associative array.\n' >&2
  exit 1
}

# --- Reject quoted array SLICES, which behave differently on bash 3.2.
#
# `"${array[@]:1}"` expands to separate words on bash 4+, and on bash 3.2 it JOINS
# them with IFS[0] instead. Every script here sets IFS=$'\n\t', so a slice passed to
# a command arrives as ONE newline-joined argument.
#
# This is not a syntax error and not a missing builtin, so neither `bash -n` nor the
# check above can see it, and Linux CI runs bash 5 where the line is correct. It was
# found by reading od(1) output on real dry-run text, which is not a repeatable way
# to catch it.
#
# Comments are excluded so the explanation of the hazard is not itself a match — the
# same false positive tests/placement-policy.sh and tests/vm.sh record.
slice_found=0
for file in "${FILES[@]}"; do
  offenders="$(awk '/^[[:space:]]*#/ { next } /\$\{[A-Za-z_][A-Za-z_0-9]*\[@\]:/ { printf "  %d: %s\n", FNR, $0 }' "$file")"
  [[ -z "$offenders" ]] && continue
  printf '%s: uses a quoted array slice, which joins on bash 3.2.\n' "$file" >&2
  printf '%s\n' "$offenders" >&2
  slice_found=1
done
((slice_found == 0)) || {
  printf 'Iterate the array with a for loop instead; macOS ships bash 3.2.\n' >&2
  exit 1
}

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x "${FILES[@]}"
  echo "Shell syntax and shellcheck: OK (${#FILES[@]} files)"
elif [[ "${REQUIRE_LINTERS:-0}" == "1" ]]; then
  echo 'shellcheck is required when REQUIRE_LINTERS=1.' >&2
  exit 1
else
  echo "Shell syntax: OK (${#FILES[@]} files); shellcheck not installed, skipped"
fi
