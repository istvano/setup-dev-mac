#!/usr/bin/env bash
# Validate the declared MCP policy.
#
# An MCP server is arbitrary code with tool access. These checks are what stop
# the policy file from looking like enforcement while providing none.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

POLICY="$ROOT/mcp/managed-settings.json"
LOCK="$ROOT/mcp/toolhive.lock"

[[ -f "$POLICY" ]] || {
  echo "Missing $POLICY" >&2
  exit 1
}

# Held in a variable rather than piped straight in, so the same validator can also be run
# against a fixture below. See the self-test after the real check for why that matters.
VALIDATOR="$(
  cat <<'PY'
import json
import re
import sys

path = sys.argv[1]
with open(path) as handle:
    policy = json.load(handle)

errors = []

# Without this the allowlist merges with user, project and local settings, so
# any of them could widen it. The file would enforce nothing.
if policy.get("allowManagedMcpServersOnly") is not True:
    errors.append("allowManagedMcpServersOnly must be true, or the allowlist is advisory")

allowed = policy.get("allowedMcpServers")
if not isinstance(allowed, list):
    errors.append("allowedMcpServers must be a list; unset means every server is permitted")
    allowed = []

if not isinstance(policy.get("deniedMcpServers", []), list):
    errors.append("deniedMcpServers must be a list")

# Package specs that resolve at run time rather than to a fixed version. Each
# of these fetches whatever upstream publishes, which is the exact pattern
# ADR-006 exists to prevent.
RESOLVERS = {"npx", "uvx", "pipx", "bunx", "pnpm", "dlx"}
UNPINNED = re.compile(r"@(latest|next|beta|canary|\*)$")


def spec_is_pinned(arg: str) -> bool:
    """A package spec must carry an explicit version."""
    if UNPINNED.search(arg):
        return False
    # Strip a leading scope so @scope/name is not mistaken for a version.
    body = arg[1:] if arg.startswith("@") else arg
    return "@" in body


for index, entry in enumerate(allowed):
    where = f"allowedMcpServers[{index}]"
    if not isinstance(entry, dict) or len(entry) != 1:
        errors.append(f"{where}: each entry must be an object with exactly one key")
        continue
    key, value = next(iter(entry.items()))

    # The documentation is explicit that serverName is not a security control:
    # the name is a label the user assigns, so any server can be called
    # "github". Allowing one here would give false assurance.
    if key == "serverName":
        errors.append(
            f"{where}: serverName is not a security control; use serverCommand or serverUrl"
        )
        continue
    if key not in ("serverCommand", "serverUrl"):
        errors.append(f"{where}: unknown key {key!r}")
        continue

    if key == "serverUrl":
        if not isinstance(value, str) or not value:
            errors.append(f"{where}: serverUrl must be a non-empty string")
            continue
        match = re.match(r"^(https?|\*)://([^/]+)", value)
        if not match:
            errors.append(f"{where}: serverUrl must start with a scheme and host")
            continue
        scheme, authority = match.group(1), match.group(2)

        # Split host from port, keeping bracketed IPv6 literals intact.
        if authority.startswith("["):
            close = authority.find("]")
            host, rest = authority[: close + 1], authority[close + 1 :]
            port = rest[1:] if rest.startswith(":") else ""
        elif ":" in authority:
            host, _, port = authority.partition(":")
        else:
            host, port = authority, ""

        loopback = host.lower() in ("localhost", "127.0.0.1", "[::1]")

        if scheme == "http" and not loopback:
            errors.append(f"{where}: plaintext http is only acceptable on loopback")

        # ToolHive assigns a random proxy port unless one is given, and a
        # wildcard port would allow any process listening on loopback to be
        # loaded as an MCP server. Fix the port instead.
        if loopback and port == "*":
            errors.append(
                f"{where}: wildcard loopback port allows any local listener; "
                "run the server with `thv run --proxy-port <port>` and pin it"
            )
        continue

    if not isinstance(value, list) or not value or not all(isinstance(a, str) for a in value):
        errors.append(f"{where}: serverCommand must be a non-empty list of strings")
        continue

    # serverCommand matches exactly, argument for argument, so a pinned command
    # in the allowlist means every unpinned variant is refused.
    program = value[0].rsplit("/", 1)[-1]
    if program in RESOLVERS:
        # Only the first non-flag argument is the package spec; everything
        # after it belongs to the server being run, not to the resolver.
        spec = next((a for a in value[1:] if not a.startswith("-")), None)
        if spec is None:
            errors.append(f"{where}: {program} invocation names no package")
        elif not spec_is_pinned(spec):
            errors.append(
                f"{where}: {program} package {spec!r} is unpinned; "
                "require an explicit version (ADR-006)"
            )

if errors:
    print(f"{path}: policy validation failed", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    raise SystemExit(1)

print(f"MCP policy: OK ({len(allowed)} allowed, "
      f"{len(policy.get('deniedMcpServers', []))} denied)")
PY
)"

python3 -c "$VALIDATOR" "$POLICY"

# Prove the validator actually validates.
#
# mcp/managed-settings.json declares "allowedMcpServers": [], which is the deliberate
# fail-closed state (mcp/README.md). But an empty list means the loop above never executes,
# so this test printed "OK (0 allowed, 0 denied)" while the serverName rejection, the
# npx/uvx pinning rule, the plaintext-http check and the wildcard-port check had not run at
# all — the ADR-029 controls AGENTS.md calls a source of truth were untested by
# construction, and an accidental emptying of the array was indistinguishable from the
# intended state.
#
# A non-empty floor would be the wrong fix, because empty is legitimate here. Running the
# validator against a fixture that MUST be rejected exercises the rules whatever the real
# file contains.
fixture="$(mktemp)"
trap 'rm -f "$fixture"' EXIT
# serverCommand is a LIST here on purpose. Given a string it trips "must be a non-empty
# list of strings" and never reaches the resolver-pinning rule, so the ADR-006 check — the
# one that stops `npx …@latest` fetching whatever upstream publishes today — would have
# stayed unexercised by a fixture that still looked comprehensive.
cat >"$fixture" <<'JSON'
{
  "allowManagedMcpServersOnly": true,
  "allowedMcpServers": [
    { "serverName": "github" },
    { "serverUrl": "http://example.com/mcp" },
    { "serverUrl": "https://127.0.0.1:*/mcp" },
    { "serverCommand": ["npx", "@modelcontextprotocol/server-github@latest"] },
    { "serverCommand": ["uvx", "some-tool"] },
    { "unknownKey": "x" }
  ]
}
JSON
if python3 -c "$VALIDATOR" "$fixture" >/dev/null 2>&1; then
  echo 'The MCP validator accepted a policy it must reject.' >&2
  echo 'The fixture contains a serverName entry, a plaintext http URL, a wildcard' >&2
  echo 'port, two unpinned resolver specs and an unknown key. If this passes, the' >&2
  echo 'checks are not running and the real policy is unverified too.' >&2
  exit 1
fi

# ToolHive is optional, so the lock file may legitimately be absent. When it is
# present it must be a complete pin: a version with no digest is not a pin.
if [[ ! -f "$LOCK" ]]; then
  echo 'ToolHive pin: not present (ToolHive is optional)'
  exit 0
fi
for key in version darwin_arm64 darwin_amd64; do
  grep -qE "^$key=..*" "$LOCK" || {
    echo "$LOCK: missing or empty '$key'" >&2
    exit 1
  }
done
for key in darwin_arm64 darwin_amd64; do
  digest="$(grep -E "^$key=" "$LOCK" | cut -d= -f2)"
  [[ "$digest" =~ ^[0-9a-f]{64}$ ]] || {
    echo "$LOCK: $key is not a sha256 digest: $digest" >&2
    exit 1
  }
done

echo 'ToolHive pin: OK'
