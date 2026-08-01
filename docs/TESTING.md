# Testing on a machine you can only reach over SSH

Written for the Intel macOS VM standing in for the Apple Silicon workstation
until it arrives (ADR-034). Every command here is short enough to retype, because
a test machine usually has no shared clipboard.

Run these **on the VM**, in `~/workspace/mac-os-setup`, unless marked otherwise.

## From the Linux host

```bash
export MAC_TEST_HOST=istvano@localhost MAC_TEST_PORT=22220
./script/sync-to-mac                 # push the working tree
./script/sync-to-mac ./script/test   # push, then run the suite there
```

`sync-to-mac` uses rsync rather than a clone: the VM may not reach the git
remote, and a clean macOS has no `git` until Xcode Command Line Tools install.
It verifies `.git` and the executable bits survived, and forwards the remote exit
status so a failing remote test fails the local command.

## What this machine cannot install

```bash
./script/platform-gaps
```

Names every declared package this architecture cannot install and which profiles
to leave out. On Apple Silicon it reports nothing to exclude and instead lists
what is testable *only* there. `./bootstrap plan` runs it too.

## Install

At the **console**, not over SSH: the Homebrew installer needs `sudo`, and the
Rancher Desktop hook needs a logged-in graphical session.

```bash
cd ~/workspace/mac-os-setup
./bootstrap install --shell zsh --profiles all
```

`all` means every profile this machine can actually install — 20 on Apple
Silicon, 19 on Intel, where `local-llm` is excluded because `lm-studio` is
arm64-only. The expansion is printed, and the exclusion comes from
`script/platform-gaps`, so nothing has to be kept in step by hand.

Do not add `--yes`. The Homebrew installer prints its SHA-256 and waits, and that
prompt is part of what is being tested.

Expect roughly 107 packages and a long run.

**Snapshot the VM once this succeeds.** Everything below is post-install; without
that snapshot a mistake costs another full run.

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

Fetch it from the Linux host afterwards:

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

## Last, because it can end the SSH session

`--with-hardening` enables the application firewall and stealth mode. Do it at
the console, with a snapshot available.
