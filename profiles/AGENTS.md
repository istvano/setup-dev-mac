# Package-profile instructions

These files define software installed directly on macOS.

## Rules

- Every added package needs an adjacent comment explaining what it does and why
  it belongs on the host rather than in a container or VM.
- Keep profiles composable and deterministic.
- Keep mutually exclusive tools in separate fragments:
  - container runtimes
  - password managers
  - outbound firewalls
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
