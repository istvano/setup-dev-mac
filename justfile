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

# Push this working tree to the test VM; MAC_TEST_HOST targets a remote Mac instead.
sync:
  ./script/sync-to-mac

# Sync, then run the test suite on the VM. The remote exit status is forwarded.
sync-test:
  ./script/sync-to-mac './script/test'

# Regenerate docs/TOOLS.md from the Brewfile purpose comments.
tools:
  ./script/tools --write

# --- Container substrate (ADR-037) ------------------------------------------

# Create or reconcile the Colima VM, shared network, registry and build cache.
substrate:
  ./script/container-substrate

# Print what substrate would do, changing nothing.
substrate-plan:
  ./script/container-substrate --dry-run

substrate-status:
  ./script/container-substrate --status

# Non-zero when the substrate is missing or has drifted.
substrate-verify:
  ./script/container-substrate --verify

# --- Local macOS test VM (ADR-036) ------------------------------------------

# Install the tart release pinned in vm/tart.lock.
tart:
  ./script/install-tart

# Build the golden macOS image from Apple's IPSW. Interactive, once per release.
vm-build:
  ./script/vm build

# Prove the golden image is both pristine and usable.
vm-seal:
  ./script/vm seal

# Discard the test VM and re-clone it from the golden image.
vm-reset:
  ./script/vm reset

vm-up:
  ./script/vm up

vm-down:
  ./script/vm down

vm-status:
  ./script/vm status

vm-ssh:
  ./script/vm ssh

# Destructive: reset the VM, install from scratch, verify. See --help for options.
test-install:
  ./script/test-install

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
