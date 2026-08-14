#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

# C_BOLD is part of the palette this library publishes to sourcing scripts even
# though nothing in this file uses it.
# shellcheck disable=SC2034
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BLUE=$'\033[34m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
  C_BOLD=$'\033[1m'
else
  C_RESET=""
  C_BLUE=""
  C_GREEN=""
  C_YELLOW=""
  C_RED=""
  C_BOLD=""
fi

log() { printf '%s[INFO]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
success() { printf '%s[OK]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die() {
  printf '%s[ERROR]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
  exit 1
}
command_exists() { command -v "$1" >/dev/null 2>&1; }

# Apple Silicon's Homebrew prefix, and deliberately the only one.
#
# /usr/local is NOT kept as a fallback, and not merely because Intel is no longer
# supported (ADR-036). On Apple Silicon that path still exists whenever an x86_64
# Homebrew has been installed under Rosetta, so a fallback would resolve to a
# translated toolchain on exactly the machine where /opt/homebrew is missing — it
# would work, slowly, with the wrong binaries, and report success. The right answer
# there is "Homebrew is not installed", which is what an empty result says.
#
# Still a list and still discovered rather than hardcoded at the call sites: the
# prefix belongs in one place, and brew_prefix's contract is "the prefix, or
# nothing", which callers already handle.
HOMEBREW_PREFIXES=(/opt/homebrew)

brew_prefix() {
  local prefix
  for prefix in "${HOMEBREW_PREFIXES[@]}"; do
    if [[ -x "$prefix/bin/brew" ]]; then
      printf '%s\n' "$prefix"
      return 0
    fi
  done
  return 1
}

# Homebrew refuses to install ANYTHING when a directory inside its prefix is not
# writable. It is a pre-flight check on its side, so a single bad directory fails
# every package with the same message: on a real install, one root-owned
# /usr/local/share/man/man8 failed 70 of 108 dependencies.
#
# /opt/homebrew belongs to Homebrew alone, so this is rarer here than it was under
# the shared /usr/local prefix — but it is not impossible, and the check is cheap
# next to seventy identical errors.
#
# Reported, never repaired. `sudo chown -R` on a system directory is exactly the
# privileged, hard-to-reverse operation AGENTS.md keeps manual — and the correct
# owner is a judgement about the machine, not something a bootstrap should assume.
unwritable_homebrew_dirs() {
  local prefix subdir
  prefix="$(brew_prefix)" || return 0
  for subdir in bin etc include lib opt sbin share var Cellar Caskroom; do
    [[ -d "$prefix/$subdir" ]] || continue
    # BSD find has no -writable, so writability is tested per directory.
    find "$prefix/$subdir" -type d -print0 2>/dev/null |
      while IFS= read -r -d '' directory; do
        [[ -w "$directory" ]] || printf '%s\n' "$directory"
      done
  done
}

require_writable_homebrew() {
  local offenders directory targets=""
  offenders="$(unwritable_homebrew_dirs)"
  if [[ -z "$offenders" ]]; then
    return 0
  fi
  warn "Homebrew's prefix contains directories your user cannot write:"
  while IFS= read -r directory; do
    [[ -n "$directory" ]] || continue
    printf '  %s\n' "$directory" >&2
    targets="${targets:+$targets }$directory"
  done <<<"$offenders"
  die "Homebrew checks this before installing and will fail EVERY package with
the same error, not only the ones that would write there. Fix the ownership, then
re-run:
  sudo chown -R $(id -un) $targets"
}

activate_homebrew() {
  local prefix
  prefix="$(brew_prefix)" || return 1
  eval "$("$prefix/bin/brew" shellenv)"
}

# macOS installs stubs at /usr/bin for python3, git, clang and others. Before the
# Xcode Command Line Tools are present, invoking one does not fail: it opens a
# GUI installer dialog. Over SSH that means a command that appears to hang, with
# the explanation on a screen nobody is looking at.
#
# `command_exists python3` therefore returns true on a machine where python3
# cannot run, which is why several scripts here guarded on it and still tripped
# the installer. `xcode-select -p` reports the state without triggering anything;
# only `xcode-select --install` does that.
developer_tools_installed() {
  [[ "$(uname -s)" == Darwin ]] || return 0
  xcode-select -p >/dev/null 2>&1
}

require_developer_tools() {
  developer_tools_installed && return 0
  die "The Xcode Command Line Tools are not installed.
/usr/bin/python3 and /usr/bin/git are stubs until they are, and running one opens
an installer dialog rather than failing, so this stops here instead. Install them
and re-run:
  xcode-select --install"
}

# Use instead of `command_exists python3` anywhere the result gates behaviour.
python3_available() {
  command_exists python3 && developer_tools_installed
}

# Apple Silicon only, and a hard failure rather than a warning.
#
# Intel used to be accepted as a development platform, because the configuration
# had to be built before the arm64 machine existed (the superseded ADR-034). It now
# exists, and the repository is tested against a local arm64 macOS guest instead
# (ADR-036), so accepting x86_64 would only offer a configuration nothing verifies:
# a different Homebrew prefix, casks that declare arch arm64, and no way to run the
# VM that the test workflow depends on.
require_supported_mac() {
  [[ "$(uname -s)" == "Darwin" ]] || die "macOS is required."
  [[ "$(id -u)" -ne 0 ]] || die "Do not run as root."
  [[ "$(uname -m)" == "arm64" ]] || die "Apple Silicon is required; this machine
reports $(uname -m). Intel support was removed in ADR-036: the workstation is now
built and tested only on arm64, against a local macOS VM."
}

# Whether this Mac can run a VM inside a VM, which decides whether a container
# runtime can be exercised inside the macOS test guest (ADR-036).
#
# Apple's Virtualization.framework supports nested virtualization only on M3 and
# later. DETECTED rather than remembered, because this repository is built on an
# M1 Pro and targets an M5 Max: a hardcoded answer would be wrong on one of the two
# machines, and the interesting one is the machine you are standing at.
#
# FEAT_NV is the architectural feature register flag for nested virtualization. The
# sysctl is ABSENT rather than 0 on hardware without it, which is why this tests the
# value rather than the exit status.
#
# The negative branch is confirmed on M1 Pro. The positive branch has not been
# observed here, so treat a "supported" answer as a claim to verify on the M5 Max
# rather than a settled fact.
nested_virtualization_supported() {
  [[ "$(sysctl -n hw.optional.arm.FEAT_NV 2>/dev/null || echo 0)" == "1" ]]
}

# Asks, and fails CLOSED when it cannot ask.
#
# The TTY check is not cosmetic. Without it, `read` blocks forever whenever stdin is
# open but nothing is going to answer — a pipeline, a CI step, an editor's task
# runner. Observed here: `./script/container-substrate | grep ...` hung for ten
# minutes on a confirmation prompt that no one could see, because the prompt went to
# stdout and stdout was the pipe.
#
# It used to work by accident: with stdin at EOF, `read` returns non-zero, `answer`
# stays empty and the match fails. That is the same fail-closed answer, but only when
# EOF happens to arrive.
#
# Automation is expected to pass --yes, which is why ASSUME_YES is checked first and
# a missing terminal is refused rather than assumed. AGENTS.md: fail closed on
# ambiguous state.
confirm() {
  local prompt="$1" answer
  if [[ "${ASSUME_YES:-0}" == "1" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    # ASSUME_YES rather than --yes: this message reaches every confirm() caller, and
    # only bootstrap and macos-defaults parse a --yes flag. Naming the flag sent the
    # other seven callers chasing an option that does not exist, which is worse than
    # no advice at all. The environment variable is the one answer that always works.
    warn "Not asking '$prompt' because there is no terminal on stdin; assuming no.
Set ASSUME_YES=1 to answer yes without a prompt (some commands also accept --yes)."
    return 1
  fi
  printf '%s [y/N] ' "$prompt"
  read -r answer
  [[ "$answer" =~ ^([yY]|yes|YES|Yes)$ ]]
}

backup_file() {
  local path="$1"
  [[ -e "$path" || -L "$path" ]] || return 0
  local backup
  backup="${path}.backup.$(date +%Y%m%d-%H%M%S)"
  cp -R "$path" "$backup"
  log "Backed up $path to $backup"
}

atomic_write() {
  local path="$1" tmp
  mkdir -p "$(dirname "$path")"
  tmp="$(mktemp "${TMPDIR:-/tmp}/workstation.XXXXXX")"
  cat >"$tmp"
  if [[ -f "$path" ]] && cmp -s "$tmp" "$path"; then
    rm -f "$tmp"
    return 0
  fi
  [[ -e "$path" || -L "$path" ]] && backup_file "$path"
  mv "$tmp" "$path"
}
