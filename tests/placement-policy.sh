#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
! grep -R -E '^[[:space:]]*(brew|cask) "(ollama|llama\.cpp|pytorch)"' "$ROOT/profiles"
! grep -R -E 'open-webui|OLLAMA_BASE_URL' "$ROOT/containers" "$ROOT/chezmoi/private_dot_config/security-ai-workstation/containers"
grep -q '"mlx"' "$ROOT/native-ai/pyproject.toml"
grep -q '"mlx-lm"' "$ROOT/native-ai/pyproject.toml"
! grep -q 'torch' "$ROOT/native-ai/pyproject.toml"
! grep -R '/var/run/docker.sock' "$ROOT/containers" "$ROOT/chezmoi/private_dot_config/security-ai-workstation/containers"
grep -q '127.0.0.1:5432:5432' "$ROOT/containers/compose.yaml"
grep -q 'no-new-privileges:true' "$ROOT/containers/compose.yaml"
echo 'Placement policy: OK'
