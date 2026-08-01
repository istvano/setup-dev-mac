set shell := ["bash", "-euo", "pipefail", "-c"]

default:
  @just --list

plan:
  ./bootstrap plan

setup:
  ./script/setup

verify:
  ./script/verify

test:
  ./script/test

render:
  ./script/render-brewfile --output /tmp/workstation.Brewfile
  cat /tmp/workstation.Brewfile

# What this machine's architecture cannot install, and which profiles to drop.
gaps:
  ./script/platform-gaps

# Push this working tree to the macOS test VM.
# Needs MAC_TEST_HOST and MAC_TEST_PORT; see script/sync-to-mac --help.
sync:
  ./script/sync-to-mac

# Sync, then run the test suite on the VM. The remote exit status is forwarded.
sync-test:
  ./script/sync-to-mac './script/test'

# Network check: confirms every Homebrew token in profiles/ still exists.
tokens:
  ./script/check-tokens

# Network check: confirms every declared VS Code extension id still exists.
extensions-check:
  ./script/check-extensions

# Install the declared VS Code extensions at their pinned versions.
extensions:
  ./script/vscode-extensions apply

extensions-diff:
  ./script/vscode-extensions --diff

extensions-verify:
  ./script/vscode-extensions --verify

# Reviewable report of pending package updates. Changes nothing.
update-report:
  ./script/update-report

# Record installed packages and applied macOS defaults for audit.
snapshot:
  ./script/snapshot

# Install the declared MCP approved catalogue (needs sudo for the system path).
mcp-policy:
  ./script/mcp-policy apply

mcp-verify:
  ./script/mcp-policy --verify

# Install ToolHive from the release pinned in mcp/toolhive.lock.
toolhive:
  ./script/install-toolhive

defaults-diff:
  ./script/macos-defaults --diff

defaults-verify:
  ./script/macos-defaults --verify

hardening:
  ./script/hardening-check --strict
