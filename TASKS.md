# Backlog

This file contains unfinished work only. Recurring installation, verification
and hardening procedures are documented in `docs/OPERATIONS.md`.

## Requires the target Mac

Linux CI cannot prove any of these. Record the results after the first install.

- [ ] Run `./script/macos-defaults --verify` and record every key this macOS
      version silently ignores. That list is version-specific and cannot be
      predicted; it belongs here once observed.
- [ ] Confirm `brew bundle check` passes for `kubernetes-cli`, the one
      corrected token still enabled. The `mitmproxy` and `wireshark-app`
      corrections are commented out in `profiles/security.Brewfile`; if they are
      re-enabled, verify them too rather than trusting the old token names.
- [ ] Generate the OpenPGP key, publish the public key to the forge, and verify
      signing end to end: `git log --show-signature -1` must report a good
      signature, not merely a successful commit. Back up the secret key and a
      revocation certificate offline.
- [ ] Confirm Rancher Desktop is configured with Moby and Kubernetes disabled.
- [ ] Add macOS integration tests once first-run behaviour has been observed.

## Workstation follow-up

- [ ] Initialise the restic repository and run a restore drill. The tooling and
      runbook are in place; the repository itself does not exist yet.
- [ ] Enable FileVault and store the recovery key offline.
- [ ] Configure encrypted Time Machine alongside the restic repository.
- [ ] Configure `granted` for the accounts in use before running cloud scans.
