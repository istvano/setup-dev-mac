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
- Do not add Ollama, llama.cpp, PyTorch or Open WebUI to the initial baseline.
- Do not add native databases, vector stores or automated scanners when a
  container provides equivalent functionality without material degradation.
- Paid or conditionally licensed software must be isolated in the appropriate
  paid/alternative fragment and documented.
- Verify current Homebrew formula/cask tokens before changing them.

## Validation

Run:

```bash
./script/render-brewfile --output /tmp/workstation.Brewfile
./tests/render-brewfile.sh
./script/test
```
