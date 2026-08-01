# Local inference runtime. Opt-in and deliberately not part of the default set.
#
# This profile is the documented exception to the "no local LLM runtime in the
# baseline" rule in profiles/AGENTS.md: LM Studio bundles llama.cpp and MLX
# engines. See ADR-025 for the reasoning and the operating constraints.
#
# Two things about this cask differ from everything else here:
#
#   1. It updates itself. The cask carries auto_updates, so new code arrives
#      without passing `brew upgrade` or ./script/update-report. Treat the app
#      as outside the reviewed update flow and check its release notes directly.
#   2. The models are the trust surface, not the app. Prefer GGUF and
#      safetensors weights; avoid pickle-backed .bin files, which execute code
#      on load.
#
# Its OpenAI-compatible server must stay on loopback: leave "Serve on Local
# Network" off, matching the serving invariant in AGENTS.md.
#
# MLX itself is NOT installed here. It is a project-local Python dependency
# (ADR-004); see docs/OPERATIONS.md#local-ai-models.
#
# The `arm64-only` marker below is machine-readable, not decoration.
# script/platform-gaps reports every package carrying it that cannot install on
# the current machine, and script/check-tokens verifies the marker against
# Homebrew's own `depends_on arch` in both directions — so it cannot go stale or
# be forgotten on a new package (ADR-034).
cask "lm-studio" # arm64-only. GUI for discovering, downloading and running local LLMs via llama.cpp and MLX.
