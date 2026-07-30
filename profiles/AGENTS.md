# Package-profile instructions

These files define software installed directly on macOS.

## Rules

- Every added package needs an adjacent comment explaining what it does and why
  it belongs on the host rather than in a container or VM.
- Keep profiles composable and deterministic.
- Keep mutually exclusive tools in separate fragments:
  - interactive shells
  - container runtimes
  - password managers
  - outbound firewalls
- The shell fragment is the only alternative without a `none`: a workstation
  always has an interactive shell, so `script/render-brewfile` appends it
  unconditionally. Do not copy the `!= none` guard onto it.
- Fonts belong in the `fonts` profile and are judged more leniently than software:
  a font executes nothing, opens no port and needs no permission. The exception is
  the Ghostty font-family font, which stays in `core` because the terminal depends
  on it; `tests/placement-policy.sh` asserts that pairing.
- Do not add a shell plugin manager. fisher, oh-my-fish and the zsh frameworks
  fetch unreviewed code at runtime, outside the Homebrew trust boundary (ADR-031).
- Keep cloud providers, Kubernetes, privileged security tools and personal
  productivity applications in explicit opt-in fragments.
- A new profile must be added to `VALID_PROFILES` in `script/lib/profiles.sh`
  and to the choices in `chezmoi/.chezmoi.toml.tmpl`; `tests/profiles.sh`
  enforces the correspondence.
- Only `homebrew/core` and `homebrew/cask` tokens. A third-party tap expands the
  trusted supply chain and needs a decision record first (ADR-020).
- A desktop utility that requires Accessibility, Screen Recording, Input
  Monitoring, Full Disk Access or a driver extension must state that in its
  purpose comment.
- Do not add Ollama, llama.cpp, PyTorch or Open WebUI to the initial baseline.
  Local inference lives in the opt-in `local-llm` profile only (ADR-025); note
  that the placement test matches literal tokens and cannot detect a bundled
  engine, so apply this rule by reading, not by trusting the check.
- Do not add a language runtime. Node, Go, Java, Rust and pnpm are declared in
  chezmoi/dot_config/mise/config.toml.tmpl (ADR-021).
- One tool per job in the default profile (ADR-022). If an installed tool
  already covers the use case, extend its configuration instead.
- Do not add native databases, vector stores or automated scanners when a
  container provides equivalent functionality without material degradation.
- Paid or conditionally licensed software must be isolated in the appropriate
  paid/alternative fragment and documented.
- Verify current Homebrew formula/cask tokens before changing them, with
  `./script/check-tokens`. Homebrew renames continuously: `mitmproxy` moved from
  a formula to a cask and `wireshark` became `wireshark-app`.

## Validation

Run:

```bash
./script/render-brewfile --output /tmp/workstation.Brewfile
./tests/render-brewfile.sh
./tests/profiles.sh
./script/check-tokens
./script/test
```
