#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys, yaml
for path in list(Path(sys.argv[1]).rglob('*.yaml')) + list(Path(sys.argv[1]).rglob('*.yml')):
    yaml.safe_load(path.read_text())
print('YAML syntax: OK')
PY
