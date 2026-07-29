# Backlog

## Before first installation

- [ ] Run `./bootstrap plan` on the new Apple Silicon Mac.
- [ ] Run `./script/test` on macOS.
- [ ] Render the selected Brewfile and verify current package/cask tokens.
- [ ] Review `chezmoi diff` before the first apply.
- [ ] Confirm FileVault recovery-key storage procedure.
- [ ] Confirm hardware security keys and Apple account recovery configuration.

## First installation validation

- [ ] Verify Rancher Desktop switches to Moby and leaves Kubernetes disabled.
- [ ] Add MLX to a representative project's uv environment.
- [ ] Verify that project's MLX workload on the M5 Max.
- [ ] Test BetterDisplay with the intended multi-monitor setup.
- [ ] Record real first-run issues as focused tasks or decisions.

## Hardening follow-up

- [ ] Review Full Disk Access, Accessibility, Screen Recording and Login Items.
- [ ] Review Remote Login, Screen Sharing, Remote Management and sharing state.
- [ ] Establish encrypted Time Machine and off-site backup.
- [ ] Create separate browser profiles for personal, corporate, cloud admin and
      security testing.
- [ ] Define short-lived cloud credential workflows before running cloud scans.

## Repository improvements

- [ ] Add macOS integration tests after observing first-run behaviour.
- [ ] Add a controlled update report before `brew bundle` or digest upgrades.

## Explicit non-goals for the initial baseline

- multiple simultaneously active container runtimes
- native PostgreSQL, Redis or Qdrant daemons
- automatic FileVault activation or recovery-key export
- automatic Rosetta installation
