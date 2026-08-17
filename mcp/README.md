# MCP policy

`managed-settings.json` is installed verbatim by `script/mcp-policy` to
`/Library/Application Support/ClaudeCode/managed-settings.json` — the managed
settings tier, which no user, project or local setting can override.

It contains no comments on purpose. Claude Code validates this file, and an
unrecognised key risks being rejected, so the explanation lives here instead.

## Why this file exists

An MCP server is arbitrary code with tool access to the machine. The usual way
to run one is `npx -y some-package@latest`, which downloads and executes
unpinned remote code with full user privileges every time an agent starts. That
contradicts ADR-006 and the rule in `AGENTS.md` against unreviewed remote-script
execution. See ADR-029.

## The rules this file follows

`allowManagedMcpServersOnly` makes the allowlist authoritative: allowlists in
user, project and local settings are ignored. Denylists still merge from every
source, so a server can always be blocked, never unblocked.

**Use `serverCommand` or `serverUrl` only.** `serverName` is not a security
control — it is a label the user assigns, so any server can be called `github`.
`tests/mcp-policy.sh` rejects a `serverName` entry in the allowlist because
accepting one would give false assurance.

**`serverCommand` matches exactly**, every argument in order:
`["npx","-y","server"]` does not match `["npx","-y","server","--flag"]`. That
exactness is the lever. Allowlist a pinned command and every unpinned variant
fails the policy, which turns ADR-006 from a principle into a check.

An empty `allowedMcpServers` array means no servers are permitted, and that was the starting
point — the array is no longer empty. Six servers are allowlisted; see the table below for
what each is and how far it is trusted. Adding one remains a deliberate act, and removing
them all is a valid fail-closed state rather than a broken file.

Because an empty array also makes the validation loop in `tests/mcp-policy.sh` execute zero
times, that test additionally runs against a fixture that must be rejected — otherwise
emptying this file would silently retire every rule it enforces.

## Two kinds of entry

A server run directly is a stdio command, so it is allowlisted by
`serverCommand` with an explicit version.

A server run under ToolHive is exposed over HTTP on loopback, so it is
allowlisted by `serverUrl`. Give it a fixed port with `thv run --proxy-port`;
a wildcard port would permit any local listener and is rejected. Use
`127.0.0.1` rather than `localhost`, because URL matching is on the literal
host.

## What is allowlisted, and how far each one is trusted

Versions were checked against npm and PyPI on 2026-08-15. Every entry is pinned, so
`npx`/`uvx` fetch that exact release rather than whatever upstream publishes next.

| Entry | Provenance | Notes |
|---|---|---|
| `@upstash/context7-mcp@4.0.2` | Upstash | Library documentation lookup. Read-only. |
| `mcp-server-fetch@2026.7.10` | Anthropic reference (PyPI) | URL retrieval. Read-only. |
| `mcp-server-git@2026.7.10` | Anthropic reference (PyPI) | Launched with no `--repository`, so the repository is chosen per call rather than pinned into this file. Adding `--repository <path>` here would scope it to one checkout, at the cost of a machine-specific absolute path in a committed file. |
| `@modelcontextprotocol/server-sequential-thinking@2026.7.4` | Anthropic reference | Reasoning aid. No I/O. |
| `mcp-remote@0.1.38 https://mcp.atlassian.com/v1/sse` | Atlassian, proxied | Jira and Confluence. |
| `slack-mcp-server@1.3.0` | **Third party** | See the warning below. |

**Jira goes through Atlassian's own remote server.** `mcp-remote` is only a stdio-to-SSE
proxy, so the trust boundary stays with Atlassian rather than with a community
reimplementation. The endpoint was verified to be real and OAuth-gated: it answers `401`
with `www-authenticate: Bearer realm="OAuth"` from `server: AtlassianEdge`. Both the proxy
version and the URL are part of the exact match, so neither can be swapped silently.

**Slack is the weak entry, deliberately recorded as such.** There is no official Slack
remote MCP endpoint that could be verified — `slack.com/api/mcp` answers
`{"ok":false,"error":"unknown_method"}` and `mcp.slack.com` merely redirects to a workspace
subdomain — and the former official package, `@modelcontextprotocol/server-slack`, is
marked on npm as *"Package no longer supported"*. So `slack-mcp-server` is community code
that will hold a Slack token and can read workspace history. It is pinned, which bounds
*which* code runs, but pinning is not review. Read its source at the pinned version before
authenticating it, or drop the entry and keep Slack on the claude.ai connector instead.

`@modelcontextprotocol/server-github` is deliberately absent for the same reason: npm marks
it no longer supported.

**A note on the claude.ai connectors.** Atlassian, Slack, Linear and the rest configured
through claude.ai are not stdio servers launched from this machine, and whether
`allowManagedMcpServersOnly` governs them was not established. Applying this policy on a
working machine without checking that first is how a day's tooling disappears; try it on
the test VM (`./script/vm ssh`) first.

## Adding a server

The full workflow, including inspection and pinning, is in
[Operations](../docs/OPERATIONS.md#mcp-servers). In short: inspect it, pin it,
add its command or URL here, apply the policy, then point the client at it.

Apply the policy *before* registering the client. `allowManagedMcpServersOnly`
means a server absent from the allowlist will not load even once the client is
configured to use it.

## toolhive.lock

ToolHive is optional and is not installed by default. This file pins the release
that `script/install-toolhive` will fetch if you choose to run it, and nothing
else depends on it: `script/update-report` skips its version check unless `thv`
is actually installed, and the test suite treats a missing lock as valid.

It is deliberately not installed through Homebrew, so this file is the only
record of which build is trusted and `brew upgrade` will never move it.
