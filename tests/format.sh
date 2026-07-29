#!/usr/bin/env bash
# Run the linters the repository already installs but never invoked.
#
# Set REQUIRE_LINTERS=1 (CI does) so a missing tool fails instead of silently
# skipping the check.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Matches indent_style/indent_size for [*.{sh,bash}] in .editorconfig. The
# extensionless scripts under script/ cannot be matched by an .editorconfig
# glob, so the flags are stated explicitly here for every discovered file.
SHFMT_FLAGS=(-i 2 -ci)

missing=()

require_or_skip() {
  local tool="$1"
  if command -v "$tool" >/dev/null 2>&1; then
    return 0
  fi
  if [[ "${REQUIRE_LINTERS:-0}" == "1" ]]; then
    echo "$tool is required when REQUIRE_LINTERS=1." >&2
    exit 1
  fi
  missing+=("$tool")
  return 1
}

if require_or_skip shfmt; then
  mapfile -t files < <("$ROOT/script/shell-files")
  shfmt -d "${SHFMT_FLAGS[@]}" "${files[@]}"
fi

if require_or_skip actionlint; then
  actionlint
fi

if require_or_skip gitleaks; then
  # Scan the working tree and the full history. This repository must never
  # contain credentials, so the check is not limited to staged changes.
  gitleaks detect --source "$ROOT" --no-banner --redact
fi

if ((${#missing[@]} > 0)); then
  echo "Formatting and lint checks: OK (skipped: ${missing[*]})"
else
  echo 'Formatting and lint checks: OK'
fi
