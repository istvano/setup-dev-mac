#!/usr/bin/env bash
# Validate the repository's YAML.
#
# Two implementations, because neither can be assumed. yamllint arrives with the
# dev profile; PyYAML is not in the standard library and macOS's Command Line
# Tools python3 does not bundle it, so on a freshly bootstrapped Mac there is a
# window where neither exists.
#
# That window used to be a hard failure: the fallback chain had no floor, so
# ./script/test died with a bare ModuleNotFoundError before the packages that
# would fix it had been installed. It now skips, and REQUIRE_LINTERS=1 turns the
# skip back into a failure — the same contract shellcheck, shfmt, actionlint and
# gitleaks already use in tests/format.sh.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if command -v yamllint >/dev/null 2>&1; then
  yamllint -d '{extends: relaxed, rules: {line-length: disable}}' \
    "$ROOT/.github/dependabot.yml" "$ROOT/.github/workflows/"*.yml
  echo 'YAML syntax: OK (yamllint)'
  exit 0
fi

if python3 -c 'import yaml' >/dev/null 2>&1; then
  python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys, yaml
for path in list(Path(sys.argv[1]).rglob('*.yaml')) + list(Path(sys.argv[1]).rglob('*.yml')):
    yaml.safe_load(path.read_text())
PY
  echo 'YAML syntax: OK (PyYAML)'
  exit 0
fi

if [[ "${REQUIRE_LINTERS:-0}" == "1" ]]; then
  echo 'yamllint or PyYAML is required when REQUIRE_LINTERS=1.' >&2
  echo 'yamllint is in profiles/dev.Brewfile.' >&2
  exit 1
fi

echo 'YAML syntax: skipped; neither yamllint nor PyYAML is installed'
