#!/usr/bin/env bash
# Validate the containerised agent tools (ADR-043).
#
# Static and offline. Nothing here pulls an image or starts a container: Linux CI has
# no Docker daemon this repository controls, and a real run would prove upstream's
# behaviour rather than this repository's. What CAN be checked without a daemon is
# every constraint ADR-043 imposes, each of which is a one-character edit away from
# silently not applying — a tag instead of a digest, a port mapping that loses its
# host part, a socket mount added to make a backend work.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib.sh
source "$ROOT/tests/lib.sh"

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

LOCK="$ROOT/agent-tools/openhands.lock"
AGENT="$ROOT/script/ai-agent"

[[ -x "$AGENT" ]] || fail "$AGENT is missing or not executable."

# --- The pin must be a complete pin.
#
# Mirrors tests/vm.sh and the ToolHive checks in tests/mcp-policy.sh: a version with
# no digest is a version number, not a pin, and would let any image run.
[[ -f "$LOCK" ]] || fail "Missing $LOCK"
for key in image version digest; do
  grep -qE "^$key=..*" "$LOCK" || fail "$LOCK: missing or empty '$key'"
done

digest="$(grep -E '^digest=' "$LOCK" | cut -d= -f2-)"
[[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] ||
  fail "$LOCK: digest is not a sha256 digest: $digest"

# The image reference must not itself carry a tag. `image=...:1.14.0` plus a digest
# reads as pinned and is not: the tag would be the visible half and the one a reader
# trusts, while docker resolves the digest — or fails confusingly when they disagree.
image="$(grep -E '^image=' "$LOCK" | cut -d= -f2-)"
[[ "$image" != *:* ]] ||
  fail "$LOCK: image must carry no tag; the digest is the version. Got: $image"

# --- The launcher must run the digest, not the tag.
#
# Asserted by name because this is the constraint most likely to be lost while making
# something work: upstream's own quickstart uses the tag, so any copy-paste from their
# documentation reintroduces it.
# shellcheck disable=SC2016  # a literal $ in the search pattern, not an expansion
assert_match 'reference="\$image@\$digest"' "$AGENT"

# The digest is verified at runtime too, not only here. A test that runs on Linux CI
# cannot protect a machine whose lock file was edited afterwards.
assert_match 'sha256:\[0-9a-f\]\{64\}' "$AGENT"

# --- Every published port binds loopback.
#
# Checked against the CODE, not the whole file. The launcher's header quotes upstream's
# `-p 8000:8000` in order to say why this repository does not use it, and matching that
# sentence would fail the very script that gets it right — which teaches the next author
# to delete the explanation rather than to keep the behaviour.
code="$(mktemp "${TMPDIR:-/tmp}/agent-tools.XXXXXX")"
trap 'rm -f "$code"' EXIT
grep -vE '^[[:space:]]*#' "$AGENT" >"$code"

# A Docker port mapping without a host part binds 0.0.0.0. This machine joins
# untrusted networks, so `--publish 8000:8000` would put an agent with filesystem
# access on every one of them. Any --publish/-p that is not 127.0.0.1-prefixed fails.
while IFS= read -r line; do
  [[ "$line" =~ (--publish|[^-]-p)[[:space:]]+127\.0\.0\.1: ]] ||
    fail "$AGENT: published port does not bind 127.0.0.1: $line"
done < <(grep -nE -- '(--publish|[^-]-p)[[:space:]]+[0-9]' "$code" || true)

# noVNC stays unpublished. The image exposes 8002 and the launcher deliberately does
# not map it; asserting the absence keeps that a decision rather than something a
# future edit can add without noticing what it opens.
refute_match '8002' "$code"

# And no tag-form reference anywhere in the code. Upstream's quickstart uses one, so a
# copy-paste from their documentation is the likely way it comes back.
refute_match 'ghcr\.io/[a-z0-9./-]+:[0-9]' "$code"

# Building the digest reference is not enough; the run has to USE it. Constructing
# `reference` correctly and then passing `$image:$version` to docker would satisfy every
# check above while running an unpinned image, which is the failure this pair closes.
# shellcheck disable=SC2016  # a literal $ in the search pattern, not an expansion
assert_match '"\$reference"' "$code"
# shellcheck disable=SC2016  # a literal $ in the search pattern, not an expansion
refute_match '\$image:' "$code"

# --- No general-purpose container gets the Docker socket.
#
# A standing security invariant, and OpenHands is the live temptation: mounting it is
# how its Docker-backend mode is enabled, so the pressure to add this comes with a
# working feature attached. Checked across all of script/, not just the launcher.
#
# Matches the MOUNT, not the word. Refusing the bare path would fail on any script that
# NAMES the socket to explain why it is not mounted, and the lesson a future author
# would take from that is to delete the explanation. Two forms, because there are two
# ways to write it: a bind spec always carries the destination colon, and --mount uses
# source=.
refute_match 'docker\.sock:' "$ROOT/script"
refute_match '(--volume|--mount|source=)[^[:space:]]*[[:space:]=][^[:space:]]*docker\.sock' "$ROOT/script"

# --- Exactly one state directory and one project mount.
#
# ADR-043 allows those two and nothing else. Counting them catches a third mount added
# for convenience — the home directory, ~/.ssh, a kubeconfig — which is the failure
# mode the security invariants name explicitly.
mounts="$(grep -cE -- '--volume ' "$code" || true)"
[[ "$mounts" -eq 2 ]] ||
  fail "$AGENT: expected exactly 2 --volume mounts (state and projects), found $mounts"

# --- The lock file is not a Homebrew end-run.
#
# ADR-044 records that neither aider nor Cline arrives through Homebrew. Nothing should
# reintroduce them here as images either; this file is for tools with no other channel.
refute_match '^image=.*(aider|cline)' "$LOCK"

printf 'Agent tools: OK\n'
