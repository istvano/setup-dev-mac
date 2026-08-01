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

# Homebrew's prefix depends on the architecture: /opt/homebrew on Apple Silicon,
# /usr/local on Intel. Hardcoding the Apple Silicon path made every shell
# activation, apply hook and terminal command a no-op on an Intel Mac.
#
# ORDER MATTERS. Apple Silicon is checked first so a Mac carrying both — a native
# arm64 install plus an x86_64 one under /usr/local reached through Rosetta —
# resolves to the native one. Reversing these would silently put a translated
# toolchain on PATH, which works, just slowly and with the wrong binaries.
HOMEBREW_PREFIXES=(/opt/homebrew /usr/local)

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
# every package with the same message: on a real Intel install, one root-owned
# /usr/local/share/man/man8 failed 70 of 108 dependencies.
#
# This is an Intel problem in practice. /usr/local is shared with the system and
# with other installers, while /opt/homebrew belongs to Homebrew alone.
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

# Apple Silicon is the target this workstation is designed for. Intel is accepted
# as a DEVELOPMENT platform so the configuration can be built and tested before
# the arm64 machine exists — which is exactly when the troubleshooting is cheap.
# It is a warning rather than a silent pass, because the two are not equivalent:
# Homebrew uses a different prefix and some casks are arm64-only.
require_supported_mac() {
  [[ "$(uname -s)" == "Darwin" ]] || die "macOS is required."
  [[ "$(id -u)" -ne 0 ]] || die "Do not run as root."
  case "$(uname -m)" in
    arm64) ;;
    x86_64)
      warn "Intel Mac. Apple Silicon is the supported target; this is a development
configuration. Homebrew installs to /usr/local rather than /opt/homebrew, and
arm64-only casks such as lm-studio cannot be installed here."
      ;;
    *) die "Unsupported architecture: $(uname -m)" ;;
  esac
}

confirm() {
  local prompt="$1" answer
  if [[ "${ASSUME_YES:-0}" == "1" ]]; then
    return 0
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
