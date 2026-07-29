#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

required_agents=(
  "$ROOT/AGENTS.md"
  "$ROOT/chezmoi/AGENTS.md"
  "$ROOT/profiles/AGENTS.md"
  "$ROOT/script/AGENTS.md"
)

for file in "${required_agents[@]}"; do
  [[ -s "$file" ]] || { echo "Missing or empty $file" >&2; exit 1; }
done

root_size="$(wc -c < "$ROOT/AGENTS.md" | tr -d ' ')"
(( root_size < 32768 )) || { echo "Root AGENTS.md exceeds 32 KiB" >&2; exit 1; }

while IFS= read -r skill; do
  head -n 1 "$skill" | grep -qx -- '---'
  grep -q '^name: [a-z0-9-][a-z0-9-]*$' "$skill"
  grep -q '^description: .\+' "$skill"
done < <(find "$ROOT/.agents/skills" -type f -name SKILL.md | sort)

skill_count="$(find "$ROOT/.agents/skills" -type f -name SKILL.md | wc -l | tr -d ' ')"
(( skill_count >= 2 )) || { echo "Expected at least two repo-local skills" >&2; exit 1; }

grep -q 'cask "codex"' "$ROOT/profiles/dev.Brewfile"

echo 'Agent context and skills: OK'
