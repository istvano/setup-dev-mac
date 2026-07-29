#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
while IFS= read -r file; do bash -n "$file"; done < <(find "$ROOT" -type f \( -name '*.sh' -o -name bootstrap -o -name executable_mlxctl -o -name executable_wsctl \) | sort)
echo 'Shell syntax: OK'
