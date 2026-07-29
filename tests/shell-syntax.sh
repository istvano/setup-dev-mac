#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Discovery is centralised in script/shell-files so this check, tests/format.sh
# and CI can never drift into linting different sets of files. The previous
# selector matched only *.sh and bootstrap, silently skipping every
# extensionless script under script/.
mapfile -t FILES < <("$ROOT/script/shell-files")

for file in "${FILES[@]}"; do
  bash -n "$file"
done

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x "${FILES[@]}"
  echo "Shell syntax and shellcheck: OK (${#FILES[@]} files)"
elif [[ "${REQUIRE_LINTERS:-0}" == "1" ]]; then
  echo 'shellcheck is required when REQUIRE_LINTERS=1.' >&2
  exit 1
else
  echo "Shell syntax: OK (${#FILES[@]} files); shellcheck not installed, skipped"
fi
