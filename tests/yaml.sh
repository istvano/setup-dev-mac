#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if command -v yamllint >/dev/null 2>&1; then
  yamllint -d '{extends: relaxed, rules: {line-length: disable}}' \
    "$ROOT/.github/dependabot.yml" "$ROOT/.github/workflows/"*.yml
  echo 'YAML syntax: OK'
  exit 0
fi

# CI and pre-bootstrap environments may provide PyYAML without yamllint.
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys, yaml
for path in list(Path(sys.argv[1]).rglob('*.yaml')) + list(Path(sys.argv[1]).rglob('*.yml')):
    yaml.safe_load(path.read_text())
print('YAML syntax: OK')
PY
