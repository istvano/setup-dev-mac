# MCP server review tooling. Opt-in.
#
# An MCP server is arbitrary code with tool access to this machine, so it is
# inspected before it is trusted, not after. See ADR-029 and mcp/README.md.
#
# ToolHive (thv), which runs each server in an isolated container, is optional
# and is NOT installed by this profile or anywhere else by default. Run
# script/install-toolhive explicitly to add it; it fetches a release pinned by
# checksum in mcp/toolhive.lock rather than using a third-party tap (ADR-020).
brew "mcp-inspector" # Official MCP inspector: shows the tools a server actually exposes.
