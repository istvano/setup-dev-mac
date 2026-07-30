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

# Network check: confirms every Homebrew token in profiles/ still exists.
tokens:
  ./script/check-tokens

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
