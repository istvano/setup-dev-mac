# Testing a real install

`./script/test` is static validation and `./script/verify` inspects a machine that
is already installed. Neither answers whether `./bootstrap install` turns a
pristine macOS into a configured workstation, and the real machine can only answer
it once.

So the repository provides a disposable macOS guest: a golden image built once from
Apple's IPSW, cloned per run (ADR-036). Most commands here run **in the guest**, in
`~/workspace/mac-os-setup`.

## From nothing to a verified install

Numbered because the order matters and several steps are slow. Times are from a real
run on the M1 Pro build machine.

### 0. Clean slate (only if starting over)

Skip on a first run. This destroys both VMs and everything in them; all of it is
declared and rebuilt by the steps below.

```bash
./script/vm destroy --golden        # the macOS test guests
colima delete default              # the container substrate VM
```

### 1. Host tooling — 2 min

```bash
./script/install-tart              # pinned release; verifies digest AND signing team
./script/install-tart --verify     # must print the pinned version
```

`~/.local/bin` must be on `PATH`, or nothing below finds `tart`. Both shell
configurations put it there; on a machine where the repository has never been
applied, export it for the session.

`k3d` is needed for the shared registry and comes from the opt-in `kubernetes`
profile. Without it the substrate skips the registry and says so.

### 2. The container substrate — 3 min

```bash
./script/container-substrate --dry-run    # read the exact commands first
./script/container-substrate              # create it
./script/container-substrate --verify     # MUST exit 0
./script/container-substrate --status
```

`--verify` must exit 0 before going further. Expected output:

```text
VM mount type          virtiofs (as declared)
VM sizing              8 CPUs / 14 GiB / 100 GiB disk (as declared)
network k3d-lan        172.30.0.0/16
registry shared-registry 127.0.0.1:5000
builder dev            present
```

**If the mount type says `sshfs`**, the profile pre-dated the declared value and
Colima discarded the flag — it cannot change this in place. The only fix is
`colima delete default` and re-running step 2. Do not ignore it: virtiofs is the
largest filesystem performance difference available.

Confirm the registry is not exposed, because a Docker port mapping without a host
part binds `0.0.0.0`:

```bash
docker inspect k3d-shared-registry --format '{{ json .HostConfig.PortBindings }}'
# expect: {"5000/tcp":[{"HostIp":"127.0.0.1","HostPort":"5000"}]}
nc -z 127.0.0.1 5000                      # must succeed
nc -z "$(ipconfig getifaddr en0)" 5000    # must FAIL
```

### 3. The golden macOS image — 45-60 min, and the one interactive step

```bash
./script/vm build
```

It generates a dedicated `~/.ssh/workstation-vm` key if absent, then downloads
Apple's IPSW (~15 GB; `UniversalMac_26.6.1` at the time of writing) and creates the
VM. Then it stops and prints a checklist, because a fresh macOS boots into Setup
Assistant and no script may click it.

Complete it by hand, in the guest window:

1. Work through Setup Assistant. Create the account **`admin`** — the name matters,
   or set `WORKSTATION_VM_USER`. Skip Apple Account, Screen Time, Siri, analytics.
2. Enable Remote Login with the GUI toggle: System Settings > General > Sharing >
   Remote Login.

   Not `systemsetup -setremotelogin on`. That needs the calling terminal to hold
   Full Disk Access and fails with "requires Full Disk Access privileges" until it
   does — a TCC grant no script may click, which is exactly the class of work
   `docs/MANUAL-SECURITY.md` keeps manual. The Settings app already holds it.

   To do it from the command line instead, load the daemon directly, which needs no
   TCC grant:

   ```bash
   sudo launchctl enable system/com.openssh.sshd
   sudo launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist
   ```

   sshd then runs even though the Sharing pane may still show Remote Login as off,
   because only `systemsetup` updates that preference. `vm seal` connects rather than
   reading the toggle.
3. From **the host**, install the key:

   ```bash
   ssh-copy-id -i ~/.ssh/workstation-vm.pub admin@$(tart ip workstation-golden)
   ```

   Then grant passwordless sudo. Both `-t` and `-i` are required, and leaving either
   out fails in a way that reads as something else:

   ```bash
   ssh -t -i ~/.ssh/workstation-vm -o IdentitiesOnly=yes \
     admin@$(tart ip workstation-golden) \
     "echo 'admin ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/admin >/dev/null \
      && sudo chmod 0440 /etc/sudoers.d/admin \
      && sudo visudo -c -f /etc/sudoers.d/admin"
   ```

   - Without `-t`: `sudo: a terminal is required to read the password`. sudo still
     wants the password at this point — that is the very thing being removed — and
     `ssh host "cmd"` allocates no terminal.
   - Without `-i`: ssh offers only default key names (`id_rsa`, `id_ed25519`, …), so
     it ignores the key just installed and asks for the account password instead.
   - `chmod 0440` because `tee` creates the file 0644, and `visudo -c` because a
     malformed file in `sudoers.d` breaks sudo *entirely* — validate it while a
     working password is still available.

   Confirm it took. This must print `SUDO-OK` with no prompt:

   ```bash
   ssh -i ~/.ssh/workstation-vm -o IdentitiesOnly=yes -o BatchMode=yes \
     admin@$(tart ip workstation-golden) 'sudo -n true && echo SUDO-OK'
   ```

   Passwordless sudo is required, not a shortcut: bootstrap uses sudo for the
   firewall, `softwareupdate` and the system-scope macOS defaults, and an unattended
   run cannot answer a password prompt.
4. Shut the guest down from the Apple menu. Cloning a running VM does not give a
   clean image.

Then prove it is fit to test against:

```bash
./script/vm seal
```

This must pass. It checks the image is usable (SSH by key, `sudo -n`, arm64) and
**pristine** — no Command Line Tools, no Homebrew, no chezmoi configuration. An
image that already has Homebrew produces an install that reports success while never
exercising the code path under test.

### 4. The destructive install test — 30-60 min per run

```bash
./script/test-install --runtime colima
```

Reset, boot, sync the working tree, install the Command Line Tools,
`./bootstrap install --yes`, `./script/verify`, the full test suite with
`REQUIRE_LINTERS=1 REQUIRE_CHEZMOI=1`, then `./script/hardening-check`. A transcript
lands in `~/.config/security-ai-workstation/vm/test-install-*.log`.

The Command Line Tools step stands in for the human. `bootstrap` deliberately runs
`xcode-select --install` and stops with "Complete the Apple installer, then rerun" —
correct for a person at a keyboard, and a wall for an unattended run. `test-install`
does what that message tells the operator to do, between the two documented passes,
rather than weakening `bootstrap`.

One thing this consequently does NOT cover: `ensure_xcode_clt`'s trigger-and-stop
path. It ends in a GUI dialog, so no unattended harness reaches it.

`--runtime colima` is the default, because the container runtime is most of what this
workstation is for. The run therefore also exercises the substrate **inside the
guest**: it checks the runtime packages installed, runs
`container-substrate --dry-run` there, and then either creates the substrate for real
or explains why it cannot.

How far it gets depends on the silicon, and `test-install` detects it from the guest:

| Host | Guest `kern.hv_support` | What the run proves |
|---|---|---|
| M3 or later | 1 | Everything: Colima starts in the guest, the network, registry and build cache are created, `--verify` passes, `docker run` works |
| Before M3 | 0 | Packages install and configure; `container-substrate` runs and emits the right commands; `--verify` correctly FAILS. Colima starting is **not** proven |

On earlier silicon Colima fails in the guest with
`VZErrorDomain Code=2, "Virtualization is not available on this hardware."` That is
the hardware, not the repository. The final machine runs Colima **natively rather than
nested**, so it is a limit on rehearsal only — but it does mean the container half of
the workstation must be proven on the M5 Max before it is relied on.

The `kubernetes` profile is in the default set (ADR-038), so `k3d`, kubectl, helm and
the rest are installed and exercised by every run without a hand-written `--profiles`
argument.

**If the first run stalls on a password prompt**, it is a cask installing a
privileged component — LuLu is the one in the default selection. Homebrew prompts
for those through its own dialog rather than `sudo`, which `NOPASSWD` does not
cover. Isolate it, then widen:

```bash
./script/test-install --runtime colima --firewall none --password-manager none
```

### 5. Repeat, to prove it is repeatable

```bash
./script/vm reset && ./script/test-install --runtime colima
```

`reset` re-clones the golden image in about a second, because Tart clones are APFS
copy-on-write. That cheapness is the whole point: a first-install test you can only
run once is a test you run once.

### 6. Check the transcript before sharing it

```bash
grep -c "Password:" ~/.config/security-ai-workstation/vm/test-install-*.log
```

Any hit needs inspecting first — see SECURITY.md, "Recorded terminal sessions".

### What is left running

`./script/vm status` and `./script/container-substrate --status` report both. Shut
them down when idle; neither VM returns memory to macOS:

```bash
./script/vm down
colima stop
```

## Reaching the guest

```bash
./script/vm up                       # boot headless, wait for SSH
./script/vm ssh                      # a shell in the guest
./script/vm status                   # what exists, how big, what is running
./script/sync-to-mac                 # push the working tree
./script/sync-to-mac ./script/test   # push, then run the suite there
```

`sync-to-mac` targets the local VM when `MAC_TEST_HOST` is unset, and a remote
arm64 Mac when it is set. It uses rsync rather than a clone, because a pristine
macOS has no `git` until the Command Line Tools are installed — the very thing
under test. It verifies `.git` and the executable bits survived, and forwards the
remote exit status so a failing remote test fails the local command.

## Install by hand

```bash
cd ~/workspace/mac-os-setup
./bootstrap install --shell zsh --profiles all --runtime none
```

`all` means every declared profile — 20 of them. The expansion is printed, because
a selection that broad should be visible in the plan.

`--runtime none` is the default for the build machine, not a simplification.
Nested virtualization needs M3 or later, so on the M1 Pro no container runtime can
start inside the guest at all; selecting one installs the cask and then reports it
could not be configured. That is the hardware, not a repository failure, and a pass
is not evidence the runtime works.

On the M5 Max it *does* work, so `--runtime colima` there is the first opportunity
to exercise hook 25 anywhere. `script/test-install` detects which machine it is on
and says which case applies rather than assuming.

`./bootstrap install` will stop almost immediately on a pristine guest:

```text
[INFO] Starting the Apple Xcode Command Line Tools installer.
[ERROR] Complete the Apple installer, then rerun ./bootstrap install.
```

That is the documented two-phase flow, not a fault. Over SSH there is no dialog to
complete, so install them from the command line and run bootstrap again:

```bash
sudo touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
softwareupdate -l          # now lists "Command Line Tools for Xcode ..."
sudo softwareupdate -i "Command Line Tools for Xcode 26.6-26.6"
sudo rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
xcode-select -p            # must print a path before continuing
```

The sentinel file is the non-obvious part: without it `softwareupdate -l` reports
"No new software available" even on a machine that has no Command Line Tools at all.
`script/test-install` does exactly this for you.

Do not add `--yes` when testing by hand. The Homebrew installer prints its SHA-256
and waits, and that prompt is part of what is being tested.

Expect a long run.

**Resetting is free, so mistakes are cheap.** `./script/vm reset` re-clones the
golden image in about a second; there is no need to snapshot before experimenting.
Apple's licence permits two macOS guests per host, which the golden image plus one
clone already uses, so run selections one at a time rather than in parallel.

## Recording a run so it can be analysed later

A long install scrolls past and the interesting part is usually the bit that
went by. `script` records the whole session, prompts and all, to a file:

```bash
script -q /tmp/install.log ./bootstrap install --shell zsh --profiles all \
  --git-name "Your Name" --git-email you@example.com
```

`script` still gives the command a terminal, so the confirmation prompts work
normally.

**Authorise sudo first, or the recording will contain your password.** `script`
captures everything that reaches the terminal, and casks that install a
privileged component — `oversight`, `lulu`, `little-snitch`, `wireshark-chmodbpf`
— prompt for one through Homebrew rather than through `sudo` itself, which means
it is echoed and recorded. Caching the credential up front means no prompt
happens inside the recorded session:

```bash
sudo -v            # authorise once, before starting the recording
script -q /tmp/install.log ./bootstrap install ...
```

A long install can outlive the default five-minute sudo timestamp, so a prompt
may still appear. Treat any recording made across a privileged install as
containing a credential until checked:

```bash
grep -c "Password:" /tmp/install.log     # any hit needs inspecting before sharing
```

If one is present, destroy the file rather than editing it — `shred -u` on the
Mac, or `rm -P` — and change the password if it is used anywhere else.

Fetch it back to the host afterwards:

```bash
grep -c "Password:" /tmp/install.log          # check BEFORE it leaves the machine
./script/sync-to-mac --fetch /tmp/install.log ./install.log
```

The file contains terminal escape sequences, because the repository colours its
output when stdout is a terminal and `script` provides one. Strip them to read
it as plain text:

```bash
sed $'s/\x1b\[[0-9;]*[a-zA-Z]//g' install.log > install.txt
```

The same works for any command worth keeping, not just the install:

```bash
script -q /tmp/verify.log ./script/verify
```

If a run has already finished and was not recorded, the transcript is gone
unless the window is still open — Terminal.app can save it with
**Shell → Export Text As…**, Ghostty cannot. The machine state is usually the
better evidence anyway; see the next section.

## After the install

```bash
./script/verify                                      # brew bundle + chezmoi doctor
REQUIRE_LINTERS=1 REQUIRE_CHEZMOI=1 ./script/test    # the linters now exist
./script/hardening-check
chezmoi managed --include=files,dirs | grep -v '^\.' # must print NOTHING
```

That last one is the regression check for chezmoi writing repository
documentation into `$HOME`.

`./script/snapshot` records installed formulae, casks, taps and the macOS
defaults diff to a dated file under
`~/.config/security-ai-workstation/snapshots/`. That is the thing to fetch back
when a run needs analysing, because it describes what is actually on the machine
rather than what scrolled past:

```bash
./script/snapshot
./script/sync-to-mac --fetch .config/security-ai-workstation/snapshots ./snapshots
```

## Switching to fish

```bash
sed -i '' 's/^shell = "zsh"/shell = "fish"/' ~/.config/chezmoi/chezmoi.toml
./script/setup --no-pager
```

Use `--no-pager` whenever the run is recorded or piped. Without it `chezmoi diff`
opens a pager that takes over the session, and under `script` there is no obvious
way out of it.

Then, in a new shell:

```bash
fish -lc 'echo $fish_key_bindings'   # fish_default_key_bindings
fish -lc 'bind ctrl-w'               # backward-kill-path-component
fish -lc 'echo $PATH' | tr ' ' '\n' >/tmp/fish.path
zsh  -lc 'echo $PATH' | tr ':' '\n' >/tmp/zsh.path
diff /tmp/zsh.path /tmp/fish.path    # order may differ, contents must not
```

A path present for zsh and missing for fish means Ghostty's `--login` argument is
not taking effect, which is invisible until a tool installed by a macOS package
cannot be found.

## Ghostty

`ghostty` is on `PATH` through a symlink chezmoi creates, because the cask ships
an app and no binary.

Ghostty is GPU-accelerated and needs Metal. Whether a Virtualization.framework
guest satisfies it is **unknown** — record what happens rather than assuming
either way. If it cannot start in the guest, that is a limit of the VM and not a
configuration fault, and the checks below have to move to the host.

```bash
ghostty +validate-config          # DO THIS FIRST — the only real check
ghostty +show-config | grep -E 'scrollback|shell-integration|^command|font-family|theme'
ghostty +list-themes | grep -i catppuccin
ghostty +list-fonts | grep -i nerd
```

**`+validate-config` is the validator; `+show-config` is not.** `+show-config`
prints values after parsing and compatibility renames, which catches a renamed or
mistyped *key* — but it does not resolve a theme, so it happily echoed a theme
name that stopped Ghostty starting. `+validate-config` resolves it and reports
`theme "…" not found`.

Theme names are Ghostty's own spelling: `+list-themes` prints `Catppuccin Mocha`,
capitalised and space-separated, not `catppuccin-mocha`.

## VS Code extensions

```bash
./script/vscode-extensions --verify
./script/vscode-extensions --diff
```

`--diff` separates three things: declared but missing, installed but undeclared,
and arriving as a pack or dependency child. On a fresh machine the middle list
should be empty.

Pinning only holds while VS Code's own updates are off. Add
`"extensions.autoUpdate": false` to
`~/Library/Application Support/Code/User/settings.json`; `--verify` warns until
you do.

## Git diff and merge in VS Code

`git diff` still uses delta in the pager; these are the on-demand external tools.

```bash
git difftool HEAD~1            # side-by-side in VS Code
git difftool --dir-diff HEAD~1 # whole changeset in one window
git mergetool                  # three-way editor on each conflicted file
```

Confirm which pane is which the first time you resolve a conflict: git passes
temp files, and `$LOCAL` is configured first so your side sits where git puts it
in conflict markers. If the panes read the other way round, swap `$LOCAL` and
`$REMOTE` in `chezmoi/dot_gitconfig.tmpl`.

Both need a graphical session. Over plain SSH `code --wait` has nothing to open.

## macOS defaults

```bash
./script/macos-defaults --diff
./script/macos-defaults apply
./script/macos-defaults --verify
```

Record every key `--verify` reports as drifted: those are the ones this macOS
version silently ignores. The list is version-specific, cannot be predicted, and
belongs in `TASKS.md` once observed.

## Bringing results back

```bash
./script/sync-to-mac --fetch <remote-path> <local-path>
```

## The firewall, which can end an SSH session

The application firewall and stealth mode are enabled by default, early in
`bootstrap install` — before `chezmoi apply`, so everything after them runs with
the firewall up. That ordering has been exercised in the guest and SSH survives:
`--getallowsigned` auto-permits Apple-signed software and `sshd` qualifies. On a
machine you can only reach remotely, prefer `--no-hardening` and enable it at the
console afterwards.

Stealth mode stops the guest answering `ping`, so use SSH rather than ICMP to
decide whether a VM is alive.
