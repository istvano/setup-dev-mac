# Local macOS test VM

`tart.lock` pins the Tart release that `script/install-tart` will fetch. Tart runs
macOS guests on Apple's Virtualization.framework, which is what lets this
repository test its own first-install procedure. See ADR-036.

## Why this exists

`./bootstrap install` is the most consequential path in the repository and the only
one nothing could exercise. `./script/test` is static validation; `./script/verify`
inspects a machine that is already installed. Running the bootstrap on the real
machine answers the question once, after which the machine is no longer pristine.

## The model

One golden image, cloned per run:

```bash
./script/install-tart      # pinned, digest- and signature-verified
./script/vm build          # macOS from Apple's IPSW; interactive, once
./script/vm seal           # prove it is pristine AND usable
./script/test-install      # reset, install from scratch, verify
```

`tart clone` is an APFS copy-on-write clone, so a fresh guest costs a second and
almost no disk. That is what makes the test repeatable rather than occasional.

## Why the pin is not a Homebrew tap

tart is carried only by a third-party tap, which ADR-020 declined for other tools.
Beyond that rule: Homebrew 6 refuses to load a formula from an untrusted tap
without an interactive `brew trust`, so it could not sit in a Brewfile at all; the
formula pulls a second tap formula, `softnet`; and the release is already
pinnable.

`tart.lock` records three things, and the installer refuses on any mismatch:

- `version` — the release to fetch
- `sha256` — the archive digest, taken from the release's own
  `tart_<version>_checksums.txt` rather than computed from the download
- `team_id` — the Apple Developer Team Identifier that signed `tart.app`

The signature check is not belt-and-braces. `tart.app` carries
`com.apple.security.virtualization` and `com.apple.vm.networking`, and those
entitlements only apply while the signature is intact — which is why the installer
keeps the whole `.app` bundle instead of copying the executable out of it.

**Licence:** tart is "Fair Source", not OSI open source: free for individuals and
small organisations, paid above a threshold. Recorded because `AGENTS.md` requires
a licence classification for every dependency.

## Golden images come from Apple

`tart create --from-ipsw` installs macOS from Apple's own image. A prebuilt
`ghcr.io/cirruslabs/macos-*` guest would be faster and arrive with SSH and
passwordless sudo ready, but it would put a third party's macOS underneath a test
of this repository's security baseline. The cost of the Apple route is one
interactive Setup Assistant pass per macOS release; `./script/vm build` prints the
checklist.

## What the VM cannot prove

- **Container runtime: depends on the machine.** Nested virtualization needs M3 or
  later. On the M1 Pro build machine no runtime starts in the guest, so
  `run_onchange_after_25_configure-container-runtime.sh.tmpl` is unprovable there;
  on the M5 Max target it can be exercised. `script/test-install` detects which
  applies via `nested_virtualization_supported` and defaults to `--runtime colima`,
  because the container runtime is most of what this workstation is for: on the M1 Pro
  the packages install and the wiring is verified while the daemon cannot start, and
  the run says so rather than passing quietly. `--runtime none` skips it explicitly.
- **Two guests per host**, per Apple's licence, on both machines. Golden plus one
  running clone is exactly two, so a profile matrix runs sequentially.
- **Ghostty needs Metal** and is unverified in a VZ guest.
- **Sizing defaults to the smaller machine**: 8 GB and 4 CPUs. Raise them with
  `WORKSTATION_VM_MEMORY_GB` and `WORKSTATION_VM_CPUS` on the M5 Max.

`TASKS.md` tracks these rather than leaving them implied.

## Bumping the pin

Change `version`, download the archive and its published
`tart_<version>_checksums.txt`, and take the digest from that file. Verify against
the upstream checksums rather than computing them from whatever the download
returned. Re-read `team_id` with `codesign -dv <path>/tart.app` and only change it
after establishing that a new signing identity is legitimate.

`brew upgrade` will never move this binary, because Homebrew did not install it.

Nothing reports a newer tart release: `script/update-report` has a ToolHive section and no
tart equivalent, so bumping this pin is something you have to remember rather than something
you are told about. Tracked in `TASKS.md`.
