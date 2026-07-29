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

# Install the local pre-commit and pre-push hooks.
hooks:
  pre-commit install --install-hooks
  pre-commit install --hook-type pre-push

defaults-diff:
  ./script/macos-defaults --diff

defaults-verify:
  ./script/macos-defaults --verify

hardening:
  ./script/hardening-check --strict
