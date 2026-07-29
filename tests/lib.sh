#!/usr/bin/env bash
# Shared assertions for the repository test suite.

# Bare `! grep ...` disables errexit for the command and treats grep's error
# status (2) as success, so a renamed or missing file makes the assertion pass
# silently. These helpers distinguish "no match" from "grep could not run".

assert_match() {
  local pattern="$1"
  shift
  local status=0
  grep -R -E -q -- "$pattern" "$@" || status=$?
  case "$status" in
    0) return 0 ;;
    1)
      printf 'Expected a match for %s in: %s\n' "$pattern" "$*" >&2
      exit 1
      ;;
    *)
      printf 'grep failed with status %s for %s in: %s\n' "$status" "$pattern" "$*" >&2
      exit 1
      ;;
  esac
}

refute_match() {
  local pattern="$1"
  shift
  local status=0
  grep -R -E -q -- "$pattern" "$@" || status=$?
  case "$status" in
    0)
      printf 'Unexpected match for %s in: %s\n' "$pattern" "$*" >&2
      exit 1
      ;;
    1) return 0 ;;
    *)
      printf 'grep failed with status %s for %s in: %s\n' "$status" "$pattern" "$*" >&2
      exit 1
      ;;
  esac
}

# Assert a command fails, without letting an unexpected success pass.
refute_command() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '%s\n' "$description" >&2
    exit 1
  fi
}
