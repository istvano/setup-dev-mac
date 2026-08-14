# Backlog

This file contains unfinished work only. Recurring installation, verification
and hardening procedures are documented in `docs/OPERATIONS.md`.

## Run the new test harness

The local macOS VM (ADR-036) exists but has not yet been exercised end to end.
Everything else in this section depends on it, so it comes first.

- [ ] `./script/vm build`, then `./script/vm seal`. Record how long the IPSW
      download and macOS install actually take, and how much disk the golden image
      claims — the guess in the design was 60-90 GB against 514 GB free.
- [x] **`seal` refuses an unfinished image, and no longer lies about why.** Run
      against a golden built but not yet through Setup Assistant it reported 4
      failures and exited 1.

      It also exposed a false-confidence bug in `seal` itself: `check_absent` reports
      PASS when its command fails, so with SSH broken all four Pristine checks passed
      for the wrong reason — "Homebrew is absent [PASS]" against a guest nothing could
      log into. That is ADR-016's failure inverted, "cannot inspect" reported as
      "correctly absent", and an image carrying Homebrew with broken SSH would have
      been declared pristine. The Pristine block is now gated on SSH and reports
      SKIP plus a failure when it cannot run; `tests/vm.sh` asserts the gate.
- [ ] Still to do: break a WORKING golden deliberately — install Homebrew in it, or
      remove `/etc/sudoers.d/admin` — and confirm each is individually reported. The
      refusal above was driven by SSH being absent, so the pristine checks themselves
      have not yet been seen to fail for the right reason.
- [x] **`./script/test-install --runtime colima --firewall none --password-manager
      none` PASSED on macOS 26.6.1, exit 0.** A pristine guest became a configured
      workstation unattended: Command Line Tools installed non-interactively,
      `bootstrap install` completed, `script/verify` reported `brew bundle complete!
      49 Brewfile dependencies now installed` and chezmoi healthy.

      The part worth keeping: the strict suite passed INSIDE the guest — all 14
      checks with nothing skipped, on the real linters the `dev` profile installs, on
      the target platform, under bash 3.2. That combination had never been exercised
      anywhere before.

      The 9 `hardening-check` failures are expected, not defects: `macos-defaults`
      was never applied, so every declared key reads unset, and `firewall_logging`
      needs `--with-hardening`. Non-strict reports and continues, which is why the
      run still passed.

      Transcript checked per SECURITY.md: mode 0600, zero `Password:` prompts.
- [ ] Run with the FULL default selection. The pass above used
      `--firewall none --password-manager none` to isolate the privileged-cask risk,
      so 49 of 51 dependencies installed — and the two skipped, `lulu` and
      `bitwarden`, are precisely the ones most likely to prompt. LuLu installs a
      system extension, and Homebrew asks for those through its own dialog rather
      than `sudo`, which NOPASSWD does not cover. Expect a stall rather than a clean
      failure; watch it rather than leaving it unattended.
- [x] Run with the macOS defaults and hardening. Both are now the default rather than
      opt-in (ADR-041). Verified in a guest: `macos-defaults --verify` reported every
      declared key in effect, `hardening-check` moved firewall and stealth to `[PASS]`
      and dropped from eight failures to two (FileVault, MCP policy), and SSH survived
      the firewall being enabled mid-bootstrap.

      This is also what exposed the `confirm()` hint naming `--yes`, a flag only
      `bootstrap` implemented — `macos-defaults apply` over ssh printed the advice and
      then rejected it, so the sudo-scoped keys could not be applied unattended at all.
      `macos-defaults` now takes `--yes`, and the hint names `ASSUME_YES=1`, which every
      caller honours.
- [ ] `./script/vm reset && ./script/test-install` a second time to time a reset and
      confirm the loop is repeatable. Reset itself has been exercised three times as
      part of the runs above and is effectively instant, but the wall-clock figure
      has not been recorded.
- [ ] Confirm the transcript in
      `~/.config/security-ai-workstation/vm/test-install-*.log` contains no
      administrator password. Casks with a privileged component prompt through
      Homebrew rather than `sudo`, so it is echoed; see SECURITY.md, "Recorded
      terminal sessions". `grep -c "Password:"` before sharing one.

## Requires the target Mac

The target is the M5 Max (128 GB, 4 TB). The repository is built and tested on an
M1 Pro (32 GB); both are `arm64`, so a result there is evidence about the target
rather than about a stand-in — unlike the Intel platform this replaced.

Linux CI cannot prove any of these. Most can now be answered in the VM on either
machine; the ones that need specific hardware are marked.

- [x] `./script/macos-defaults apply` then `--verify` on macOS 13.7.8:
      **no key was found to be ignored.** All 53 declared settings are in effect.

      The two apparent findings were both faults in the verifier, not in macOS,
      and both were "cannot inspect" reported as "not applied" — the failure
      ADR-016 exists to prevent:

      - `read_setting` used `sudo defaults read` for system scope. Reading
        `/Library/Preferences` needs no privilege; requiring it made four
        SoftwareUpdate keys unreadable wherever sudo could not prompt, and each
        was reported as unset.
      - `action_firewall_logging_verify` matched `enabled`, but macOS answers
        `Log mode is on`. A correctly applied setting reported as drifted
        forever, and disagreed with `script/hardening-check`, which matched
        `enabled|on` and passed the same machine.

      Re-check on the current macOS: the answer is version-specific, and a newer
      release is the more likely one to have dropped a key.
- [ ] Confirm `brew bundle check` passes for `kubernetes-cli`, the one
      corrected token still enabled. The `mitmproxy` and `wireshark-app`
      corrections are commented out in `profiles/security.Brewfile`; if they are
      re-enabled, verify them too rather than trusting the old token names.
- [ ] Generate the OpenPGP key, publish the public key to the forge, and verify
      signing end to end: `git log --show-signature -1` must report a good
      signature, not merely a successful commit. Back up the secret key and a
      revocation certificate offline. **Host, not the VM** — the key must not be
      generated in a guest that gets destroyed.
- [ ] **Not testable in the VM on the M1 Pro; testable on the M5 Max.** Confirm
      Rancher Desktop is configured with Moby and Kubernetes disabled. Nested
      virtualization needs M3 or later, so on the build machine no container runtime
      starts in the guest and
      `run_onchange_after_25_configure-container-runtime.sh.tmpl` is unproven there.
      On the target it can be exercised in the VM — see the ADR-036 follow-up below.
      Until then, do it on the host.
- [ ] Prove the lab boundary: `limactl start`, then `ansible -i lab, -m ping all`.
      The isolated-VM domain was documented but unimplemented until ADR-027, so
      it has never actually been exercised. Host, since it is itself a hypervisor.
- [ ] **Does Ghostty run in a VZ guest at all?** It is GPU-accelerated and needs
      Metal. Whether paravirtualized graphics satisfy it is unknown; record the
      answer rather than predicting it. If it cannot start there, every Ghostty
      check below moves to the host permanently, and that limitation belongs in
      ADR-036.
- [ ] `ghostty +validate-config` exits 0, and with fish selected
      `ghostty +show-config | grep -E 'shell-integration|^command'` reports `fish`
      and the `--login` argument. Ghostty is the only thing that launches fish, so
      a rejected `command` line would leave zsh running with no error anywhere.
- [ ] With fish selected, compare `PATH` against zsh's. They should differ only
      in ordering. A missing `/etc/paths.d` entry means `--login` is not taking
      effect, which is invisible until a tool installed by a macOS package is
      not found.
- [x] `./script/test` passes, all 13 test scripts, with
      `REQUIRE_LINTERS=1 REQUIRE_CHEZMOI=1` and nothing skipped: shellcheck over
      38 files, shfmt, actionlint, gitleaks, chezmoi template execution across 20
      templates x 3 configurations, and yamllint. The bash 3.2 constraint holds.
      Previously four of these skipped silently on this machine because the tools
      were not installed, and the suite still printed "All repository tests
      passed" — which is why `REQUIRE_*` is now in the documented command set.
- [ ] After the first `chezmoi apply`, confirm nothing landed in `$HOME` that is
      not a dotfile: `chezmoi managed --include=files,dirs | grep -v '^\.'` must
      print nothing.
- [ ] With the `dev` profile, confirm `./script/vscode-extensions --verify` passes
      and that `--diff` reports the ten pack children rather than calling them
      undeclared.
- [ ] Set `"extensions.autoUpdate": false` in VS Code settings, or accept that
      the pinned versions will drift and `--verify` will keep reporting it.
- [ ] On the first `git mergetool`, confirm the VS Code panes are the way round
      the config assumes. `code --merge` takes path1, path2, base, result, and
      `$LOCAL` is passed first so your side matches git's ours-before-theirs
      ordering — but which pane VS Code labels as which could not be established
      from its source. Swapped panes would resolve conflicts the wrong way while
      looking normal.

## Follow-up from ADR-037 (Colima)

The runtime swap is declared and tested statically; none of it has been exercised on
real hardware yet.

- [x] **Substrate created and verified on the M1 Pro.** `--verify` exits 0 with all
      four objects as declared: VM 8 CPUs / 14 GiB / 100 GiB, network `k3d-lan` on
      172.30.0.0/16, registry on 127.0.0.1:5000, buildx builder `dev`. Docker 27.4.0
      reachable through the `colima` context; buildx builds and loads; a container
      attached to `k3d-lan` received 172.30.0.2; the VM is reachable at its
      `--network-address` IP.
- [x] **`--verify` refuses when it should.** Deleting the network, removing the
      builder and republishing the registry on all interfaces were each reported, and
      all together produced the right failure count. The registry case was confirmed
      to be a real exposure first: with `--port 5000` the LAN address answered on
      5000; with `--port 127.0.0.1:5000` it did not.
- [x] **Registry is loopback-only.** Docker records
      `{"5000/tcp":[{"HostIp":"127.0.0.1","HostPort":"5000"}]}`, the OCI catalogue
      answers on loopback, and the LAN address is closed.
- [x] **virtiofs required deleting the profile, and that is now detected.** Colima
      discards `--mount-type` on an existing profile with a single warning line and
      starts on the old value; the guest was mounting `fuse.sshfs` while the
      repository declared virtiofs. `--status` and `--verify` now read the mount type
      back from the profile. After `colima delete default` and a rebuild the guest
      mounts `type virtiofs (rw,relatime)` and `--verify` is green.

      This is the ADR-016 failure applied to Colima: declared, stored, ignored. Any
      future setting that Colima refuses to change in place needs the same read-back
      treatment rather than trust in the flag.
- [ ] Test whether `cpuType: host` does anything under `--vm-type=vz`. The
      `--cpu-type` flag documents itself in terms of `qemu-system-aarch64 -cpu help`,
      so it looks like a QEMU-only setting and therefore inert on Virtualization
      .framework. If so, the research document's "pin the CPU type" step and its
      stop/start cycle can be dropped.
- [ ] Migrate off Rancher on the build machine following
      `docs/OPERATIONS.md#migrating-from-rancher-desktop`, and confirm `which -a
      docker kubectl` shows nothing under `~/.rd/bin` afterwards.
- [ ] Create a k3d cluster against the substrate and confirm the shared registry
      avoids a re-pull: create a second cluster and check images come from the
      registry rather than the network. That is the claim the registry exists for.
- [ ] Decide whether `docker-buildx` and `docker-compose` belong in
      `runtime-colima.Brewfile` or in a shared fragment. OrbStack bundles its own
      compose, so selecting orbstack currently gets no buildx from this repository.
- [ ] Watch Apple's `container`. It reached 1.0 and gives each container its own VM,
      which is better isolation than any Docker-compatible runtime here. It is
      excluded only because it does not implement the Docker API, so Compose and
      Testcontainers cannot use it. Re-evaluate when that changes.

## Follow-up from ADR-036

- [ ] Decide whether `mcp/toolhive.lock`'s `darwin_amd64` digest and
      `script/install-toolhive`'s `x86_64` branch should go. They are now
      unreachable — `require_supported_mac` fails on Intel first — but
      `tests/mcp-policy.sh` requires the key to be present, so removing it is a
      three-file change and was left out of the Intel sweep deliberately rather
      than by oversight.
- [ ] Verify `nested_virtualization_supported` returns true on the M5 Max. Only its
      negative branch is confirmed, on the M1 Pro, where `hw.optional.arm.FEAT_NV`
      is absent. If the sysctl is not the right signal on M3+ silicon, every
      container-runtime claim below rests on a detector that always says no.
- [ ] On the M5 Max, run `./script/test-install --runtime rancher` and confirm
      `run_onchange_after_25_configure-container-runtime.sh.tmpl` actually
      configures Moby with Kubernetes disabled. This is the hook that has never
      been exercised anywhere, and the M5 Max is the first machine that can.
- [ ] Consider whether `WORKSTATION_VM_DISK_FORMAT=asif` should become the default.
      It performs better and the host qualifies (macOS 26), but `raw` is the proven
      path and the difference has not been measured here.
- [ ] `script/update-report` reports newer ToolHive releases only when `thv` is
      installed. Give tart the same treatment so a stale `vm/tart.lock` is noticed.

## Findings from the first destructive runs

Each of these stopped a run dead and none was visible by reading the code.

- [x] **`sync-to-mac` did not quote the remote command.** `remote_command` joined
      arguments with a space, and ssh hands the joined string to the remote login
      shell, which parses it again — so any argument containing a space was split
      back apart:

          ./bootstrap install ... --git-name Workstation Test ...
          [ERROR] Unknown option: Test

      The destructive test could therefore never have passed with a multi-word Git
      name, which is the normal case. Both `remote_command` and `script/vm`'s
      `vm_ssh` now re-quote with `printf '%q'`; `tests/vm.sh` asserts the expression
      in both files.

      The same fix had already been applied to `vm_ssh` an hour earlier and was not
      carried across. Nothing noticed, because no test passed a multi-word argument.

- [x] **`vm build` and `seal` cannot install the Command Line Tools, and bootstrap
      correctly refuses to continue without them.** `ensure_xcode_clt` runs
      `xcode-select --install` and stops with "Complete the Apple installer, then
      rerun" — right for a person, a wall for an unattended run.

      `script/test-install` now installs them itself, standing in for the human
      between the two documented bootstrap passes. `bootstrap` is unchanged: its
      fail-fast is correct and weakening the product to test the product is the wrong
      trade.

      The non-obvious part is that `softwareupdate -l` reports "No new software
      available" even on a machine with no Command Line Tools at all, until the
      on-demand sentinel exists:
      `/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress`.

      Verified live in the guest: `Command Line Tools for Xcode 26.6` downloaded and
      installed, confirmed by reading `xcode-select -p` back rather than trusting the
      installer's exit status.

- [ ] Not covered, and cannot be: `ensure_xcode_clt`'s trigger-and-stop path itself.
      It ends in a GUI dialog, so no unattended harness reaches it. Everything after
      it is what a run proves.

## Open review findings

- [x] `confirm()` in `script/lib/common.sh` called `read` with no terminal check, so
      in any non-interactive context with stdin open — a pipeline, CI, an editor task
      runner — it blocked forever instead of failing closed. Observed as a
      ten-minute hang on `./script/container-substrate | grep ...`, with the prompt
      written to the pipe where nobody could see it. It only ever failed closed by
      accident, when stdin happened to be at EOF. It now refuses without a terminal
      and says so; `--yes` remains the documented way to answer yes. This affected
      every confirming command in the repository, not just the new ones.

Found while reviewing the repository; none are fixed yet except where noted.

- [x] `bootstrap` set `umask 077` in a function body, which leaked to the rest of
      the process — including `chezmoi init --apply` and therefore
      `brew bundle install` for the whole selection. Both shell configurations here
      already record that Homebrew fails to build several formulae under umask 077.
      Now scoped to a subshell.
- [x] `script/sync-to-mac` joined the remote command with `"$*"` under
      `IFS=$'\n\t'`, so it joined on a NEWLINE and a multi-word command became
      several commands. `sync-to-mac ./script/macos-defaults --dry-run` would have
      run `./script/macos-defaults`, whose default mode is apply. Fixed, and
      `tests/vm.sh` now guards against it in all three scripts.
- [ ] `script/macos-defaults --section <typo>` passes vacuously: the section name
      is never validated, so `selected()` matches nothing, every counter stays 0
      and `--verify` reports "All declared macOS defaults are in effect" and exits
      0. Contradicts the principle stated in `script/shell-files`,
      `script/vscode-extensions` and `script/check-tokens`.
- [ ] `script/install-toolhive` absorbs unknown arguments instead of rejecting
      them, so a mistyped `--verify` reinstalls the binary it was asked to inspect.
      `script/install-tart` was written with an explicit rejection arm; port it.
- [ ] Missing-value guards are inconsistent across option parsers. `snapshot`,
      `macos-defaults`, `test-install` and `vm` check; `bootstrap` (11 options) and
      `render-brewfile` (6) do not, so `--git-name --yes` sets the name to `--yes`
      and leaves `ASSUME_YES` unset. Lift `require_value` out of
      `script/test-install` into `script/lib/common.sh` and use it everywhere.

## MCP follow-up

The approved catalogue and container isolation are in place (ADR-029). What
remains cannot be settled from documentation alone.

- [ ] Verify `allowManagedMcpServersOnly` is a key Claude Code actually honours.
      The entire control rests on it, `mcp/README.md` notes that an unrecognised
      key risks the file being rejected, and it could not be confirmed offline.
- [ ] Confirm whether Codex and opencode expose any allowlist or policy
      mechanism for MCP servers. Neither could be verified from their published
      documentation, so both are currently reviewed by hand rather than
      enforced. If a mechanism exists, extend `script/mcp-policy` to it.
- [ ] Install and prove the policy on the Mac: `./script/mcp-policy apply`, then
      `claude mcp add --transport http test https://example.com/mcp` must be
      refused by enterprise policy.
- [ ] Run the first server under ToolHive and confirm it holds no host
      credentials.

## Workstation follow-up

- [ ] Initialise the restic repository and run a restore drill. `backup` is now
      part of the default selection, so the tooling installs; the repository
      itself still does not exist.
- [ ] Enable FileVault and store the recovery key offline.
- [ ] Configure encrypted Time Machine alongside the restic repository.
- [ ] Configure `granted` for the accounts in use before running cloud scans.
