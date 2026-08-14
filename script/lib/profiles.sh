#!/usr/bin/env bash

# Shared shell-side profile catalogue. Chezmoi's Go template keeps a matching
# list because it cannot source shell data.
# Consumed by sourcing scripts (bootstrap, script/render-brewfile, tests).
# shellcheck disable=SC2034
DEFAULT_PROFILES="core,dev,security,productivity,backup,kubernetes"
VALID_PROFILES=(
  core
  dev
  security
  security-extra
  security-scan
  backup
  local-llm
  lab
  docs
  fonts
  mcp
  cloud
  cloud-aws
  cloud-azure
  cloud-gcp
  kubernetes
  data
  productivity
  productivity-extra
  paid
)

validate_profiles() {
  local requested="$1" profile valid match seen=","
  local requested_profiles=()

  [[ -n "$requested" && "$requested" != ,* && "$requested" != *, && "$requested" != *,,* ]] ||
    die "Profiles must be a non-empty comma-separated list."

  IFS=',' read -r -a requested_profiles <<<"$requested"
  for profile in "${requested_profiles[@]}"; do
    match=false
    for valid in "${VALID_PROFILES[@]}"; do
      if [[ "$profile" == "$valid" ]]; then
        match=true
        break
      fi
    done
    [[ "$match" == true ]] || die "Unknown profile: $profile"
    [[ "$seen" != *",$profile,"* ]] || die "Duplicate profile: $profile"
    seen+="$profile,"
  done
}
