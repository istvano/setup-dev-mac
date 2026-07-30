#!/usr/bin/env bash
# Validate the declared VS Code extension list.
#
# An extension runs inside the editor with the editor's filesystem access, so the
# list is held to the same standard as the MCP catalogue in ADR-029: an exact
# version on every entry and a stated purpose. A floating version would install
# whatever the marketplace serves at apply time, which is the thing pinning exists
# to prevent — and it would still work, so nothing would notice.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib.sh
source "$ROOT/tests/lib.sh"

DECLARED="$ROOT/vscode/extensions.list"
[[ -f "$DECLARED" ]] || {
  echo "Missing $DECLARED." >&2
  exit 1
}

python3 - "$DECLARED" <<'PY'
import re
import sys
from pathlib import Path

# publisher.name@version  # purpose
#
# Marketplace ids are case-sensitive as published (EditorConfig.EditorConfig,
# golang.Go), so case is not normalised here; only duplicates are compared
# case-insensitively, because `code --install-extension` matches without regard
# to case and two spellings would install one extension twice.
entry = re.compile(
    r"^(?P<id>[A-Za-z0-9][A-Za-z0-9-]*\.[A-Za-z0-9][A-Za-z0-9-]*)"
    r"@(?P<version>\d+(?:\.\d+)*)"
    r"[ \t]+#[ \t]+(?P<purpose>\S.*)$"
)

path = Path(sys.argv[1])
seen: dict[str, int] = {}
active = 0
failures = []

for number, line in enumerate(path.read_text().splitlines(), 1):
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        continue
    match = entry.fullmatch(line)
    if not match:
        failures.append(
            f"{path.name}:{number}: expected "
            f"'publisher.name@version  # purpose', got: {line}"
        )
        continue
    active += 1
    key = match.group("id").lower()
    if key in seen:
        failures.append(
            f"{path.name}:{number}: {match.group('id')} is already "
            f"declared on line {seen[key]}."
        )
    seen[key] = number

if not active:
    failures.append(
        f"{path.name}: no active entries. The parser or the file is broken; "
        "an empty declared set would make apply and verify pass vacuously."
    )

# Commented entries are documentation, but a malformed one is a trap: it will be
# uncommented one day and fail then, in an apply rather than in CI.
for number, line in enumerate(path.read_text().splitlines(), 1):
    stripped = line.lstrip()
    if not stripped.startswith("#"):
        continue
    candidate = stripped[1:]
    if not re.match(r"^[A-Za-z0-9][A-Za-z0-9-]*\.[A-Za-z0-9]", candidate):
        continue  # prose, not a commented-out entry
    if not entry.fullmatch(candidate.rstrip()):
        failures.append(
            f"{path.name}:{number}: commented entry would not parse if enabled: "
            f"{candidate.strip()}"
        )

if failures:
    for failure in failures:
        print(failure, file=sys.stderr)
    raise SystemExit(1)

print(f"  {active} active, {len(seen)} unique ids")
PY

# The script must never uninstall. An extension the user added by hand is theirs;
# reconciling it away would be a surprise, and this repository lists removal
# candidates rather than removing them (see script/update-report).
refute_match 'uninstall-extension' "$ROOT/script/vscode-extensions"

# --force is what makes a repeated apply a cheap no-op rather than a prompt.
assert_match 'install-extension.*--force' "$ROOT/script/vscode-extensions"

# The chezmoi hook must embed the declared list, or editing the list changes
# nothing until an unrelated hook happens to change.
hook="$ROOT/chezmoi/run_onchange_after_35_vscode-extensions.sh.tmpl"
assert_match 'vscode/extensions.list' "$hook"
assert_match 'has "dev" \.profiles' "$hook"

echo 'VS Code extensions: OK'
