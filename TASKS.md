# Backlog

This file contains unfinished work only. Recurring installation, verification
and hardening procedures are documented in `docs/OPERATIONS.md`.

## QA review, ten fixes applied

A QA pass over the whole repository found 25 defects; ten were fixed. Each fix has a
regression guard that was checked to FAIL when the fix is reverted, so none of them is a
comment pretending to be a test.

- [x] **False greens.** `hardening-check` compared `$1` to `--strict` positionally, so
      `--stict`, `-s` and `--verbose --strict` all reported their FAILs and exited 0 — the
      gate that exists to run before granting a machine credentials. `macos-defaults
      --section <typo>` matched no rows, examined nothing, and printed "All declared macOS
      defaults are in effect"; the valid names now come from the declarations themselves,
      so the zero-match case cannot exist. `test-install`'s chezmoi gate treated an
      unreachable guest as a settled apply; the guest now reports its own exit status and
      the absence of that line is a failure.
- [x] **Vacuous tests.** `tests/vm.sh` satisfied its `PIPESTATUS[0]` and
      `exercise_guest_substrate` assertions from comments in `test-install`, so the
      destructive driver could have been made unable to fail, and all fourteen guest
      checks deleted, with the suite green. Both are anchored now.
      `tests/chezmoi-templates.sh` ran four purely-static checks *after* its
      chezmoi-not-installed exit — including the unguarded-hook-tail check whose own
      comment records three incidents where one failing hook cost every later hook. They
      now run before it.
- [x] **Silent misconfiguration.** `bootstrap` had eleven unguarded `"$2"; shift 2` arms,
      so `--git-email --yes` wrote `--yes` as the commit address and lost the flag;
      `require_value` moved from `test-install` into `script/lib/common.sh` and is called
      from `bootstrap` and `render-brewfile`. Hook 30 lost the whole apply chain on a
      directory-bound Mac, because `pipefail` killed the assignment before the guard
      written for that case. Hook 40 applied zero defaults on any apply without a TTY, and
      only looked correct because `bootstrap --yes` exports `ASSUME_YES`. `~/.docker` is
      now ignored unless colima is selected, verified by rendering `.chezmoiignore` for all
      four runtimes.

### Second pass: ten more fixed

- [x] **Destructive on a typo.** `sync-to-mac` had a bare `case` on `$1` with no reject
      arm, so `--dryrun` became the remote command and performed a real
      `rsync -az --delete`; it now parses leading options in a loop and rejects anything
      option-shaped, while still accepting a positional remote command and `--`.
      `install-toolhive` treated any unrecognised argument as "install", so `--verfiy`
      re-downloaded and overwrote the binary it was asked to inspect.
- [x] **Wrong results.** `sync-to-mac`'s tar fallback extracted to
      `~/workspace/setup-dev-mac` instead of `$REMOTE_DIR`, then blamed a missing `.git`
      and advised a flag no script implements. `container-substrate` kept two separate
      colima flag arrays under a comment claiming one, and they had diverged on
      `--mount-type` — dry-run honoured the override, apply hardcoded virtiofs, on the one
      setting that cannot be changed after the VM exists; there is now a single
      `build_vm_start_args`. `test-install` ran colima-specific checks for every non-`none`
      runtime, so the `--runtime rancher` run TASKS.md itself prescribes failed ~7 checks
      for unrelated reasons.
- [x] **Untested controls.** `container-substrate --verify` reported "matches the declared
      state" while examining no registry at all, because every registry check hung off
      `command_exists k3d` with no else — silently retiring the loopback-binding check.
      Missing k3d is now a failure (`SUBSTRATE_REGISTRY_REQUIRED=false` to accept it).
      `tests/mcp-policy.sh` validated nothing, since the real allowlist is legitimately
      empty; the validator now also runs against a fixture that must be rejected, which
      exercises the serverName, plaintext-http, wildcard-port and both ADR-006 pinning
      rules. Verified by making the fixture valid and confirming the test then fails.
- [x] **Silent damage.** `--with-touchid-sudo` replaced an existing
      `/etc/pam.d/sudo_local` with no copy kept whenever it lacked the exact
      `auth sufficient pam_tid.so` form; it is now backed up after the prompt, so
      declining leaves nothing behind. The age hook exited 0 when `age-keygen` was
      missing and, being `run_once_` with static content, was recorded as done and never
      retried — leaving SOPS unusable with nothing reporting it. It now renders whether
      `age-keygen` exists, so installing age changes the content hash and the next apply
      creates the identity.
- [x] **`user.signingkey` broke SSH signing for two of the three recommended key
      sources.** git treats the value as a file path under `gpg.format=ssh`, rescuing only
      keys beginning `ssh-`. Measured by signing a commit with each form: raw
      `ecdsa-sha2-nistp256` exits 128 with `Couldn't load public key`, raw `ssh-ed25519`
      succeeds, and `key::` works for every type. So every Secretive key (the Secure
      Enclave is ECDSA-only) and every YubiKey `sk-` key failed on *every* commit, because
      `commit.gpgsign` is true. `key::` is now applied only to values that look like a
      public key, leaving a file path or a GPG key ID untouched.

- [x] **Third pass: the last four QA findings closed** (commit `037d7fd`). `script/tools`'
      `count_entries` returned `"0\n0"` because `grep -c` prints the count *and* exits 1 —
      now `|| true` plus `${n:-0}`, since a missing file prints nothing at all.
      `container-substrate` accepted either registry name but inspected only
      `k3d-$REGISTRY`, so a hand-created loopback registry read as world-exposed and the
      offered remediation could not work — there is now a shared `registry_container_name()`
      and `apply` refuses to recreate what k3d did not create. `script/update` parsed no
      arguments (so `--no-pager` did nothing) and diffed a different source than it applied;
      both now take one source. The weak assertions were anchored: `vscode --force` no longer
      matches the dry-run branch, the `arm64-only` refutation matches declaration lines via
      awk, and hook 25's `--verify` calls are pinned rather than its echo strings.

      **Still genuinely open:** the Ghostty theme check remains shape-only. It rejects a
      lowercase-hyphenated theme name but cannot tell a valid Ghostty theme from an invalid
      one — `theme = mocha` passes the test and would still stop Ghostty starting. Only
      `ghostty +validate-config` on a machine with Ghostty installed can catch that.

- [x] **Documentation drift corrected (F24).** `README.md` and `docs/TESTING.md` both
      claimed `--runtime none` was the `test-install` default when it is colima — and
      `TESTING.md` contradicted itself 86 lines apart, in the runbook followed for a
      destructive run. `ARCHITECTURE.md` still described macOS defaults as applied "when
      requested" after ADR-041 made them default. `AGENTS.md` and `docs/OPERATIONS.md` said
      four checks skip silently; there are **five** — the fifth is the atuin config parse in
      `tests/placement-policy.sh`, which needs a Python 3.11+ for `tomllib` that no profile
      declares. `script/install-toolhive` told the operator to start Rancher Desktop, which
      a default install no longer has. The 53-settings figure is annotated in place as
      historical (now 50 + 2 = 52); the "51 to 64" ceiling rationale was corrected when the
      ceiling reached 70.

      Counts were measured rather than recalled: `SETTINGS` and `ACTIONS` counted from
      `script/macos-defaults`, checks counted from the `TESTS` array, and skip points found
      by grepping for what each test actually prints.

- [x] **Resolved: ssh signing under Bitwarden.** The open question was that with
      `gitSigningMethod=ssh` and `passwordManager=bitwarden`, `gpg.ssh.program` is unset (it
      is only written for 1Password), so git shells out to `ssh-keygen`, which reads
      `$SSH_AUTH_SOCK` and never consults `~/.ssh/config` — the Bitwarden `IdentityAgent`
      therefore had no effect on signing and every commit failed.

      The considered fix was exporting `SSH_AUTH_SOCK` from the shell configuration, which
      would have changed the agent for *all* ssh use. It was not taken. Instead SSH keys are
      now generated per machine and kept on disk
      (`run_onchange_after_12_ssh-key.sh.tmpl`), and `private_dot_ssh/config.tmpl` names the
      file with `IdentityFile` rather than pointing at an agent — so `ssh-keygen` signs
      against the key directly and the problem does not arise.

      Verified by signing a commit with `SSH_AUTH_SOCK` unset and no agent running: exit 0.
      1Password keeps its agent, where the keys genuinely live in the agent.

- [x] **The age restore from Bitwarden is verified, both call sites.** This was the one
      unproven path that costs real data if wrong: a new Mac that mints a second identity
      cannot read anything encrypted to the first.

      Tested in the guest against a throwaway Bitwarden account holding a scratch key —
      never the real vault, because that guest has passwordless sudo, a passphraseless
      shared SSH key, and `bw login` persists credentials to a disk image that gets deleted.

      Round trip, using the key the guest had already minted so nothing of value was
      involved: stored it as an `age-identity` secure note, deleted the local copy, then

      - `./script/identity --restore` returned the **same** public key
        (`age1mnnlgyycud…`), mode 0600, marker removed, and `--check` went from FAIL to
        all-PASS.
      - The **hook's** own branch — the one a real `bootstrap install` runs — was exercised
        by clearing chezmoi's `scriptState` bucket so `run_once` hook 15 re-ran with
        `BW_SESSION` exported. It printed `Restored the age identity from Bitwarden` and
        left no marker: it restored rather than minting.

      Both implementations of `bw get notes` are therefore proven, not just the operator-
      facing one. What is still unexercised is the failure path where the item exists but
      the key sits in a custom field rather than the notes body — the hook hides that behind
      `2>/dev/null` and it is indistinguishable from a locked vault.

- [x] **bootstrap's Command Line Tools installer is verified.** It was the last code path
      no run had executed: `script/test-install` installs the CLT itself before running
      bootstrap, so bootstrap short-circuited on `xcode-select -p` and its own installer —
      the on-demand sentinel, the `softwareupdate -l` label scrape, `sudo softwareupdate -i`
      and the read-back — existed only in a form nothing had run.

      `./script/vm reset && ./script/test-install --skip-clt` against a pristine guest, exit
      0, 32 PASS, guest suite green:

          [INFO] Skipping the harness CLT step; ./bootstrap will install them.
          [INFO] Installing the Xcode Command Line Tools. This needs sudo and takes a few minutes.
          [INFO] Installing: Command Line Tools for Xcode 26.6-26.6
          [OK]   Xcode Command Line Tools are installed.

      The fragile part is the label scrape: it depends on the sentinel existing first (before
      it, `softwareupdate -l` does not offer the package at all) and on the sed pattern
      matching Apple's exact wording, here "Command Line Tools for Xcode 26.6-26.6" on macOS
      26.6.1. A future wording change is what the GUI fallback exists for.

      Still unexercised by design: that GUI fallback, which needs a human at the console.

## Configuration gaps still open

- [ ] **`k9s` has no configuration**, and the `kubernetes` profile is a default that installs
      13 binaries and configures none of them. Deferred rather than guessed: k9s 0.51.0
      writes its `config.yaml` only on first interactive run, which needs a TTY and a
      reachable cluster, so a config authored here could not be validated before shipping —
      and an invalid one breaks k9s at startup. Do it on a machine with a cluster: let k9s
      generate its defaults, then bring the diff back. The settings worth having are a
      read-only default for production contexts, and a skin matching the Catppuccin palette
      the rest of the machine uses.
- [ ] **`gh` has no configuration** (no editor, pager, protocol or aliases). Same reason to
      be careful for a different cause: `gh config set` rewrites `~/.config/gh/config.yml`,
      so a chezmoi-managed copy is a file the tool also writes — the conflict ADR-037
      records for Rancher Desktop. Decide whether to manage it with a `modify_` script that
      preserves gh's own keys, or to leave it alone deliberately and record that.
- [x] **`bat`'s Catppuccin theme was investigated and is fine.** A review flagged the missing
      `themes/` directory and absent `bat cache --build` as a silent-fallback bug. It is not:
      `bat --list-themes` in a provisioned guest lists all four Catppuccin variants, built in
      since bat 0.26.0. Recorded in `chezmoi/dot_config/bat/config` so it is not
      re-investigated.

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

      **Not reproducible as written.** `firewall_logging` no longer exists — macOS 26
      removed `socketfilterfw --getloggingmode`, so the check was deleted from both
      `script/macos-defaults` and `script/hardening-check` — and `--with-hardening` is now
      the default rather than a flag. A comparable run today reports 2 failures, not 9.
      Kept as the record of what that run observed, not as a target to match.

      Transcript checked per SECURITY.md: mode 0600, zero `Password:` prompts.
- [x] **Run with the FULL default selection — done, repeatedly.** An earlier pass used
      `--firewall none --password-manager none` to isolate the privileged-cask risk, leaving
      `lulu` and `bitwarden` — precisely the two most likely to prompt — untested. LuLu
      installs a system extension, and Homebrew asks for those through its own dialog rather
      than `sudo`, which NOPASSWD does not cover, so a stall rather than a clean failure was
      the expected failure mode.

      It did not stall. Every recent run used `test-install`'s defaults, which are the full
      default profile set plus `--firewall lulu --password-manager bitwarden`, and all
      completed with exit 0 — including the `--skip-clt` run that also installed the Command
      Line Tools from bootstrap itself. 70 packages, 32 PASS, guest suite green.
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
      **no key was found to be ignored.** All 53 declared settings were in effect.

      That count is historical and no longer matches: the table now declares **50
      settings plus 2 actions = 52**, because `firewall_logging` was removed when macOS 26
      dropped `socketfilterfw --getloggingmode`. Left as recorded rather than silently
      restated, since it is evidence of what a specific run on a specific OS observed —
      but do not expect to reproduce 53, and note that this evidence predates the removal.

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
      corrected token still enabled. (`mitmproxy` is no longer commented out and no longer in
      `security.Brewfile` — it is live in `security-extra`. Only `wireshark-app` is still
      commented out.) The `mitmproxy` and `wireshark-app`
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
      41 files, shfmt, actionlint, gitleaks, chezmoi template execution across 24
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
- [ ] Benchmark the substrate, on the M5 Max, and record numbers rather than settings.
      ADR-037 claims the configuration is on the fast path for every knob Colima
      exposes; it does NOT claim parity with OrbStack, because nothing here has
      measured either. Colima has never even started on the build machine. Worth
      measuring: an arm64 image build with a warm buildx cache, the same build
      amd64 under Rosetta versus `SUBSTRATE_VM_ROSETTA=false`, and a dependency
      install run twice — once on the `~/workspace` bind mount, once in a named
      volume — since that pair is the claim in "File I/O" that most needs a number.
- [ ] Confirm `--vz-rosetta` actually engages once Rosetta is installed. The flag is
      now a default and the guard only proves Rosetta is PRESENT on the host, not
      that Colima used it. Check inside the guest: an amd64 container should report
      x86_64 and run at Rosetta speed rather than QEMU speed.
- [ ] Watch Apple's `container`. It reached 1.0 and gives each container its own VM,
      which is better isolation than any Docker-compatible runtime here. It is
      excluded only because it does not implement the Docker API, so Compose and
      Testcontainers cannot use it. Re-evaluate when that changes.

## Follow-up from ADR-036

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

Found while reviewing the repository. **All of these are now fixed** — the entries are
kept as the record of what was wrong and how it was verified.

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
- [x] **Fixed.** `script/macos-defaults --section <typo>` passed vacuously: the section name
      is never validated, so `selected()` matches nothing, every counter stays 0
      and `--verify` reports "All declared macOS defaults are in effect" and exits
      0. Contradicts the principle stated in `script/shell-files`,
      `script/vscode-extensions` and `script/check-tokens`.
- [x] **Fixed.** `script/install-toolhive` absorbed unknown arguments instead of rejecting
      them, so a mistyped `--verify` reinstalls the binary it was asked to inspect.
      `script/install-tart` was written with an explicit rejection arm; port it.
- [x] **Fixed.** Missing-value guards were inconsistent across option parsers. `snapshot`,
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
- [ ] **Manual:** give Terminal.app a colour scheme, or decide deliberately not to.
      Ghostty's `theme =` applies to Ghostty and nothing else, so the built-in
      terminal shows whatever profile it was left on — verified as the stock `Basic`
      on the build machine, with only the six Apple profiles present. Import a
      `.terminal` profile (Catppuccin publishes them), then Terminal > Settings >
      Profiles > select > Default.

      Two things to know before bothering. **Terminal.app has no truecolor**, only
      256 colours, so a Catppuccin profile fixes the 16 ANSI colours and the
      shell prompt while `bat` (pinned to `--theme="Catppuccin Mocha"`), delta,
      eza and starship keep emitting hex and get approximated. Close, not
      matching, and worst exactly where colour carries meaning — diffs and syntax
      highlighting. That is Terminal.app, not something a profile fixes.

      And **`script/macos-defaults` cannot express the colours.** Its rows are
      `category|scope|domain|key|type|value` with scalar types only; Terminal's
      colours are archived `NSColor` blobs inside a per-profile `Window Settings`
      dictionary. Making this reproducible needs a `.terminal` file shipped and
      imported, which is a new mechanism rather than a new row. The profile
      SELECTION is expressible — `Default Window Settings` and
      `Startup Window Settings` are plain strings, two ordinary rows.

      So the open decision is whether Terminal.app is in scope at all. ADR-022
      makes Ghostty the terminal, and `vscode/README.md`'s boundary — "the scripts
      do not edit settings.json, that file is yours" — arguably covers a Terminal
      profile too. Doing it by hand costs two minutes; automating it crosses a
      stated boundary and should be an ADR amendment, not a quiet addition.

## AI coding agents (ADR-043, ADR-044)

Everything here is a macOS-only check. The tools are declared and the static
invariants are enforced by `tests/agent-tools.sh`, but four claims could not be
verified from a Linux workstation and are therefore not yet proven.

- [ ] Find Cline's telemetry opt-out, or establish that there is none. `cline hub
      start` on an idle guest — no credentials, no task — opens and holds a TLS
      connection to `otel.cline.bot`, confirmed by the certificate CN. `DO_NOT_TRACK=1`,
      `CLINE_TELEMETRY_DISABLED=1` and `OTEL_SDK_DISABLED=true` set together do NOT stop
      it, re-confirmed against that peer specifically. cline is installed on every
      default machine (`"npm:cline"` sits in the `dev` block and `dev` is in
      `DEFAULT_PROFILES`), and ADR-046's audit never covered it — the correction is in
      that ADR. Look for a config key or build flag; if there is none, the question
      becomes whether a default-profile tool may report usage at all, which is an
      ADR-044 and ADR-046 decision rather than a fix. The payload was not inspected,
      so "what it sends" is still unknown.
- [ ] Determine whether the Cline CLI auto-updates in the background, and turn it
      off if it can be. Its `postinstall.mjs` refers to a background auto-update
      restarting the hub, which would mean `"npm:cline"` pins the version
      installed once rather than the version running — the LM Studio problem
      recorded in `profiles/local-llm.Brewfile`. Record the answer in ADR-044
      either way; a pin that does not hold must not be documented as one.
- [ ] Find the OpenHands frontend's telemetry opt-out. The image carries a
      baked-in PostHog key, so the web UI reports usage by default.
- [ ] Check file ownership after OpenHands writes to a project. The container
      runs as uid 10001 while Colima presents host files as the login user's uid.
      If writes land wrong, fix it in the launcher and record why — do not reach
      for `--user`, which would make the image's own home unwritable.
- [ ] Decide who creates `~/projects`. `script/ai-agent openhands` refuses when the
      projects directory is absent, which it is on a machine that has just been
      installed — so the first `just openhands` on a new Mac fails with a correct
      but unexpected error. Either the launcher creates it or `docs/OPERATIONS.md`
      says to; it should not be discovered by hitting it.

## Telemetry follow-up (ADR-046)

- [ ] Exercise the gcloud arm of hook 31. It is the one telemetry setting never
      run: `cloud-gcp` is opt-in, so no `./script/test-install` selection has ever
      installed `gcloud-cli`, and the other two arms in that hook were both broken
      in ways only running them revealed. Install with `--profiles
      core,dev,cloud-gcp` and confirm `gcloud config get-value
      disable_usage_reporting` reads `True` afterwards.

## Pin hygiene

- [ ] Merge Dependabot's pull requests, or repin by hand — but do not leave them
      open. The question of whether it was enabled is answered: it is, and it
      opened PR #1 for actions/checkout one minute after the repository was
      created. That PR sat unmerged for nineteen days and Dependabot closed it
      itself once the same bump was made by hand. Nothing is broken except the
      habit. `script/update-report` now reports stale action pins so the drift
      shows up where updates are already reviewed; auto-merge is declined in
      `.github/dependabot.yml` and the reasoning is there.
