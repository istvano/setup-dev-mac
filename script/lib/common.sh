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

require_macos_arm64() {
  [[ "$(uname -s)" == "Darwin" ]] || die "macOS is required."
  [[ "$(uname -m)" == "arm64" ]] || die "Apple Silicon arm64 is required."
  [[ "$(id -u)" -ne 0 ]] || die "Do not run as root."
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
