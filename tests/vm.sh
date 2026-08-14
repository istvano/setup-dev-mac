#!/usr/bin/env bash
# Validate the local macOS VM tooling.
#
# Everything here is static or offline. Nothing in this file boots a guest: Linux
# CI has no Virtualization.framework, and even on the target Mac a real run costs
# a macOS install. What CAN be checked without a VM is the part that has bitten
# this repository before — argument handling that silently does the wrong thing,
# a pin that is not actually a pin, and a driver that cannot fail.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib.sh
source "$ROOT/tests/lib.sh"

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

VM="$ROOT/script/vm"
INSTALL_TART="$ROOT/script/install-tart"
TEST_INSTALL="$ROOT/script/test-install"
LOCK="$ROOT/vm/tart.lock"

for file in "$VM" "$INSTALL_TART" "$TEST_INSTALL"; do
  [[ -x "$file" ]] || fail "$file is missing or not executable."
done

# --- The pin must be a complete pin.
#
# Mirrors the ToolHive checks in tests/mcp-policy.sh: a version with no digest is
# a version number, not a pin, and would let any archive install.
[[ -f "$LOCK" ]] || fail "Missing $LOCK"
for key in version sha256 team_id; do
  grep -qE "^$key=..*" "$LOCK" || fail "$LOCK: missing or empty '$key'"
done
digest="$(grep -E '^sha256=' "$LOCK" | cut -d= -f2)"
[[ "$digest" =~ ^[0-9a-f]{64}$ ]] ||
  fail "$LOCK: sha256 is not a sha256 digest: $digest"
# An Apple Team Identifier is 10 uppercase alphanumerics. Checked because the
# signature gate compares against this string, and a typo would turn a real
# control into one that can never pass.
team="$(grep -E '^team_id=' "$LOCK" | cut -d= -f2)"
[[ "$team" =~ ^[A-Z0-9]{10}$ ]] ||
  fail "$LOCK: team_id is not an Apple Team Identifier: $team"
# No amd64 digest: there is no Intel build, and listing one would imply this works
# on a platform ADR-036 removed.
refute_match '^darwin_amd64=' "$LOCK"

# --- install-tart must verify what it claims to verify.
#
# The digest and the signing team are the whole trust story for a binary installed
# outside Homebrew. Asserted by name because a refactor could drop either while the
# script still appeared to work — it would install, every time, from anything.
assert_match 'shasum -a 256' "$INSTALL_TART"
assert_match 'Checksum mismatch' "$INSTALL_TART"
assert_match 'codesign --verify --strict' "$INSTALL_TART"
assert_match 'EXPECTED_TEAM' "$INSTALL_TART"
# The whole signed bundle, not the bare executable: the virtualization entitlement
# only applies while the signature is intact.
assert_match 'tart\.app' "$INSTALL_TART"

# --- Unknown arguments must be rejected, not absorbed.
#
# script/install-toolhive treats any unrecognised argument as "install", so a
# mistyped --verify reinstalls the binary it was asked to inspect. These scripts
# have the same shape and must not repeat it.
refute_command 'script/vm accepted an unknown command.' \
  "$VM" definitely-not-a-command
refute_command 'script/vm accepted an unknown option.' \
  "$VM" destroy --definitely-not-an-option
refute_command 'script/install-tart accepted an unknown option.' \
  "$INSTALL_TART" --verfiy
refute_command 'script/test-install accepted an unknown option.' \
  "$TEST_INSTALL" --definitely-not-an-option

# --- An option that takes a value must reject a missing one AND a following flag.
#
# `--profiles --shell fish` used to set the profile list to "--shell" and then fail
# on "fish", naming the wrong argument.
refute_command 'script/test-install accepted --profiles with no value.' \
  "$TEST_INSTALL" --profiles
refute_command 'script/test-install accepted an option as a value.' \
  "$TEST_INSTALL" --profiles --shell fish
refute_command 'script/test-install accepted an invalid profile.' \
  "$TEST_INSTALL" --profiles core,definitely-not-a-profile
refute_command 'script/test-install accepted an invalid shell.' \
  "$TEST_INSTALL" --shell bash

# --- Subcommands that take no arguments must say so.
refute_command 'script/vm up accepted a stray argument.' "$VM" up stray

# --- Neither script may join arguments with "$*".
#
# script/sync-to-mac did, and because every script here sets IFS=$'\n\t' it joined
# on a NEWLINE: a multi-word remote command became several commands. The failure
# could invert intent, since ./script/macos-defaults with no argument means apply.
for file in "$VM" "$TEST_INSTALL" "$ROOT/script/sync-to-mac"; do
  # awk rather than grep, because the thing that makes "$*" safe is on the LINE
  # BEFORE it: `local IFS=' '`. A per-line grep cannot see that, and a check that
  # cannot see the fix reports the fixed code as broken — so it would be deleted,
  # and then the real regression would go unnoticed.
  #
  # Comments are skipped. All three files explain this hazard in prose, and
  # matching the explanation instead of the code is the false positive
  # tests/chezmoi-templates.sh records for its `*fi*` glob: a test that looks
  # like it works and does not.
  offenders="$(awk '
    /^[[:space:]]*#/ { next }
    /local IFS=/ { guarded = 1; next }
    /"\$\*"/ { if (!guarded) printf "  %d: %s\n", FNR, $0 }
    { guarded = 0 }
  ' "$file")"
  [[ -z "$offenders" ]] || fail "$(basename "$file") joins arguments with \"\$*\"
without setting a local IFS first:
$offenders
IFS is \$'\\n\\t' in these scripts, so \"\$*\" joins on a NEWLINE and a multi-word
command becomes several commands. Pass \"\$@\", or set a local IFS of one space
on the line before."
done

# --- The default runtime must be colima, and the substrate must be exercised.
#
# The workstation this repository provisions is a Docker, Kubernetes and AI development
# machine, so the container runtime is most of the deliverable and the guest exists to
# rehearse it. The default was briefly `none`, reasoned from "nested virtualization
# needs M3 or later" — but that only ever justified not CREATING the substrate, never
# skipping the provisioning of the runtime itself.
assert_match '^RUNTIME="colima"$' "$TEST_INSTALL"

# The definition AND the call, each anchored.
#
# `assert_match 'exercise_guest_substrate'` matched the prose at test-install:16, so the
# function and its only call site could both be deleted — taking all fourteen guest_check
# assertions with them — and this file stayed green off a comment. An unanchored name is
# not evidence that the code exists.
assert_match '^exercise_guest_substrate\(\) \{$' "$TEST_INSTALL"
assert_match '^ *exercise_guest_substrate$' "$TEST_INSTALL"

# How far it can go is detected from the GUEST, not assumed from the host. Anchored to
# the live sysctl call for the same reason: the bare string appears in two comments.
assert_match 'sysctl -n kern\.hv_support' "$TEST_INSTALL"

# --- The destructive driver must be able to fail.
#
# It pipes everything through tee for the transcript, and a pipeline reports tee's
# status. Without PIPESTATUS the driver would exit 0 whatever happened, which is
# the one defect that makes a test suite worse than none.
#
# Anchored to the assignment. `PIPESTATUS\[0\]` alone also matched the explanatory comment
# directly above it in test-install, so `status=$?` could have replaced the real line with
# this test none the wiser — the driver would then have reported success for every failed
# install, which is precisely the defect the paragraph above calls unforgivable.
assert_match '^ *status="\$\{PIPESTATUS\[0\]\}"$' "$TEST_INSTALL"

# --- seal must check both halves.
#
# Usable alone is not enough: a golden image that already carries Homebrew or the
# Command Line Tools produces a green install that never exercised the code path
# under test.
assert_match 'check_absent .Xcode Command Line Tools' "$VM"
assert_match 'check_absent .Homebrew is absent' "$VM"
assert_match 'check_usable .Passwordless sudo' "$VM"

# The pristine checks must be GATED on SSH working.
#
# check_absent reports PASS when its command fails, so with SSH broken every absence
# check passes for the wrong reason — the connection failed, not the thing was
# missing. Seen for real on a golden image before Setup Assistant was completed:
# "Homebrew is absent [PASS]" against a guest nothing could log into. An image
# carrying Homebrew with broken SSH would have been declared pristine, which is worse
# than either fault alone.
assert_match 'if ! ssh_ready; then' "$VM"
assert_match 'CANNOT BE RUN' "$VM"

# vm_ssh must re-quote its arguments for the remote shell.
#
# ssh does not execute argv remotely: it joins the arguments with spaces and the
# remote login shell parses the result again, so quoting the local shell removed is
# gone. `sh -c '[ "$(uname -m)" = arm64 ]'` arrived as `sh -c [ ... ]` and produced
# "[: missing `]'" on every guest — and because check_absent treats a failed command
# as absence, the Homebrew check passed whether or not Homebrew was installed.
# Matched on the CODE, not the prose. Both files explain this hazard at length, and
# `assert_match "printf '%q'"` matched the explanation — passing even with the fix
# deleted. Same self-referential trap as the platform-gaps grep.
# shellcheck disable=SC2016  # a literal pattern to find, not an expansion
assert_match 'command\+="\$separator\$\(printf .%q. "\$arg"\)"' "$VM"

# sync-to-mac must quote too, for the same reason and in the same way.
#
# It was fixed here twice. First `local IFS=' '` replaced newline-joining, which was
# necessary and not sufficient: ssh still hands the joined string to the remote login
# shell, so an argument containing a space is split back apart. The first real
# destructive run died on it —
#   ./bootstrap install ... --git-name Workstation Test ...
#   [ERROR] Unknown option: Test
# — meaning the test could never have passed with a multi-word Git name.
#
# Asserted in both files because one was fixed and the other was not, and nothing
# noticed until a guest actually ran the command.
# shellcheck disable=SC2016
assert_match 'command\+="\$separator\$\(printf .%q. "\$arg"\)"' "$ROOT/script/sync-to-mac"

# No seal check may depend on remote shell syntax surviving that round trip. A bare
# `test`, or comparing output locally, cannot break the same way.
while IFS= read -r match; do
  fail "$(basename "$VM") runs a check through 'sh -c':
  $match
ssh re-parses the joined command, so the quoting is fragile and a broken check_absent
silently reports absence. Use a bare 'test', or compare output locally."
done < <(awk '/^[[:space:]]*#/ { next } /check_(usable|absent)[^\n]*sh -c/ { printf "%d: %s\n", FNR, $0 }' "$VM")

# --- The golden image comes from Apple's IPSW, not a third-party guest image.
#
# A prebuilt image would be someone else's macOS underneath a test of this
# repository's security baseline. See ADR-036.
assert_match '\-\-from-ipsw' "$VM"
refute_match 'ghcr\.io' "$VM"

# --- tart memory is set in MEGABYTES.
#
# `tart set --memory 8` is eight megabytes, and the guest fails to boot with
# nothing useful in the log. The conversion must stay visible.
assert_match 'MEMORY_GB \* 1024' "$VM"

# --- The container substrate (ADR-037).
#
# Static checks only: creating it needs a 14 GiB VM, and CI has neither
# Virtualization.framework nor the disk.
SUBSTRATE="$ROOT/script/container-substrate"
[[ -x "$SUBSTRATE" ]] || fail "$SUBSTRATE is missing or not executable."

refute_command 'container-substrate accepted an unknown option.' \
  "$SUBSTRATE" --definitely-not-an-option

# Every published port must name a host address. A Docker port mapping without one
# binds 0.0.0.0, which for an unauthenticated image registry means every network this
# laptop joins. This is the repository's own invariant, and the reason the default is
# a variable rather than a literal buried in a command.
# Single quotes throughout: these are literal patterns to find in another file, so
# the dollar signs must NOT expand here. That is the whole point of the assertion.
# shellcheck disable=SC2016
assert_match '^REGISTRY_HOST="\$\{SUBSTRATE_REGISTRY_HOST:-127\.0\.0\.1\}"$' "$SUBSTRATE"
# shellcheck disable=SC2016
assert_match 'REGISTRY_HOST:\$REGISTRY_PORT' "$SUBSTRATE"
# k3d registry create must never be handed a bare port.
while IFS= read -r match; do
  # shellcheck disable=SC2016
  case "${match#*:}" in
    *'--port "$REGISTRY_HOST:'* | *'--port %q'*) continue ;;
  esac
  fail "container-substrate publishes a port without a host address:
  $match
That binds 0.0.0.0. Use \$REGISTRY_HOST:\$REGISTRY_PORT."
done < <(awk '/^[[:space:]]*#/ { next } /--port/ { printf "%d: %s\n", FNR, $0 }' "$SUBSTRATE")

# Rosetta must stay opt-in: AGENTS.md forbids installing it automatically, and
# --vz-rosetta requires it.
assert_match '^VM_ROSETTA="\$\{SUBSTRATE_VM_ROSETTA:-false\}"$' "$SUBSTRATE"

# --verify must be able to fail. A verification command that always exits 0 gates
# nothing (script/AGENTS.md).
assert_match 'substrate check\(s\) failed' "$SUBSTRATE"

# The substrate owns no service with data. That is the whole boundary ADR-037 draws
# against ADR-010, and it is one careless addition away from being lost.
refute_match '(docker|k3d)[[:space:]]+run[[:space:]]' "$SUBSTRATE"
refute_match '(postgres|mysql|redis|kafka|mongo|elasticsearch|grafana|prometheus)' \
  "$SUBSTRATE"

# The VM must not be started by an apply hook: it is minutes of work and 14 GiB of
# standing memory, so it is the operator's decision (ADR-037).
hook="$ROOT/chezmoi/run_onchange_after_25_configure-container-runtime.sh.tmpl"
[[ -f "$hook" ]] || fail "$hook is missing."
while IFS= read -r match; do
  fail "$(basename "$hook") starts the container VM during chezmoi apply:
  $match
Report the state and name the command instead; the VM is a standing 14 GiB cost."
done < <(awk '/^[[:space:]]*#/ { next } /colima start/ { printf "%d: %s\n", FNR, $0 }' "$hook")
# It must still report the substrate rather than ignoring it.
assert_match 'container-substrate' "$hook"

# The harness must prove chezmoi finished, not merely that bootstrap exited. An install
# interrupted inside a run_onchange hook leaves the rest pending, and without this gate a
# half-configured guest passed the whole suite — the visible symptom was a broken
# terminal, which pointed the investigation at Ghostty rather than the unfinished apply.
# Definition and call site, anchored — the bare name also appears in this gate's own log
# strings, so an unanchored match proved neither.
assert_match '^assert_chezmoi_settled\(\) \{$' "$ROOT/script/test-install"
assert_match '^ *assert_chezmoi_settled$' "$ROOT/script/test-install"

# And it must read chezmoi's output ALONE. remote() is script/sync-to-mac, which prints
# "[INFO] Syncing..." and "[OK] Synced" to stdout; capturing those made the output never
# empty, so the settled branch was unreachable and the pending-hook grep ran against
# harness prose. The marker is what keeps the two streams apart.
# The pipes are escaped: assert_match greps with -E, where a bare | is alternation, so
# 'CHEZMOI|/' would assert "CHEZMOI" OR "/" and match nearly every line in the file.
assert_match 'sed "s/\^/CHEZMOI\|/"' "$ROOT/script/test-install"
assert_match "sed -n 's/\\^CHEZMOI\\|//p'" "$ROOT/script/test-install"

# The gate must FAIL CLOSED when it cannot inspect the guest.
#
# Tagging alone was not enough and briefly made things worse: with stderr discarded and
# the exit status dropped, an unreachable guest produced the same empty string as a
# settled one, and empty was the PASS — so a destructive run could report "every file and
# hook is applied" about a guest it never reached. The guest now reports its own exit
# status, and the ABSENCE of that line is a failure. Both halves are asserted because
# either one alone restores the inversion.
# Both sides, separately. Asserting the tag alone matched the host-side extraction, so the
# guest could stop emitting it and this stayed green — leaving a gate that can only ever
# die. Fail-closed rather than falsely green, but still broken, and still unnoticed.
# shellcheck disable=SC2016
# The single quotes are correct: $rc is part of the pattern being searched for in
# test-install, where it must stay unexpanded so it resolves in the guest.
assert_match 'echo "CHEZMOI-RC\|\$rc"' "$ROOT/script/test-install"
assert_match "sed -n 's/\\^CHEZMOI-RC\\|//p'" "$ROOT/script/test-install"
assert_match 'Could not read chezmoi status from the guest' "$ROOT/script/test-install"

echo 'Local macOS VM and container substrate: OK'
