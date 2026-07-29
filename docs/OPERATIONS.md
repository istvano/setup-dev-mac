# Operations

This runbook covers installation, application, verification, hardening and
package reconciliation. Architecture belongs in `ARCHITECTURE.md`; durable
rationale belongs in `DECISIONS.md`; unfinished work belongs in `TASKS.md`.

## Before first installation

1. Read the selected Brewfile fragments and all `chezmoi/run_*` scripts.
2. Run the static validation suite:

   ```bash
   ./script/test
   ```

3. Preview the default choices:

   ```bash
   ./bootstrap plan
   ```

4. Render the intended package state and review every entry:

   ```bash
   ./script/render-brewfile --output /tmp/workstation.Brewfile
   ```

5. On macOS, verify the current Homebrew formula and cask tokens.
6. Decide where the FileVault recovery key will be stored offline.
7. Confirm Apple account recovery and two hardware security keys.

## Install

The interactive path is:

```bash
./bootstrap install
```

An explicit installation using the free defaults is:

```bash
./bootstrap install \
  --profiles core,dev,security,productivity \
  --runtime rancher \
  --password-manager bitwarden \
  --firewall lulu \
  --git-name "Your Name" \
  --git-email "you@example.com" \
  --with-hardening
```

The bootstrap validates Apple Silicon macOS, establishes the documented trust
set, writes the reviewed choices to chezmoi data and applies the source state.
It does not enable FileVault, install Rosetta, modify Touch ID PAM, enable
network services or install a major macOS upgrade.

Add only the specialist profiles required by current work. For example:

```bash
./bootstrap plan \
  --profiles core,dev,security,productivity,cloud,cloud-aws,kubernetes
```

Provider profiles are separate so selecting one cloud does not install
credentials and control-plane clients for all three.

## First-install verification

Review the apply boundary and validate the resulting workstation:

```bash
chezmoi diff
./script/verify
./script/hardening-check
```

Also verify manually:

- Rancher Desktop uses Moby and leaves Kubernetes disabled.
- BetterDisplay works with the intended monitors and has only required
  permissions.
- A representative Apple Silicon project can run `uv add mlx` and its
  workload.
- Full Disk Access, Accessibility, Screen Recording and Login Items contain
  only reviewed applications.
- Remote Login, Screen Sharing, Remote Management and other sharing services
  match the intended state.

Record reproducible first-run defects in `TASKS.md` or an architectural
decision when the resolution changes a durable boundary.

## Apply repository changes

Preview and apply the current checkout:

```bash
chezmoi diff
./script/setup
```

Pull a fast-forward update, review it and apply:

```bash
./script/update
```

Neither command should be used when the repository diff or security state is
ambiguous.

`./script/verify` reads the configured chezmoi profile and alternative choices,
renders that exact Brewfile and checks it with Homebrew Bundle before running
`chezmoi doctor`.

### Migrating an older configuration

Configurations created before the current data keys existed need
`gitSigningMethod`, `gitSigningKey`, `workGitDir` and `workGitEmail` added to
`data` in `~/.config/chezmoi/chezmoi.toml`. `gitSigningMethod` is one of `gpg`,
`ssh` or `none`; an empty `gitSigningKey` disables signing regardless, and an
empty `workGitEmail` disables the work identity split.

If the data predates removal of the empty `ai` profile, remove `ai` from
`data.profiles`, along with the obsolete `syncNativeAi` and `pythonVersion`
keys; MLX and Python versions are entirely project-owned.

## Browser profiles

Selecting `productivity-extra` installs Chrome and Firefox Developer Edition.
Chezmoi then creates private `personal` and `work` data roots for both browsers
and installs the `browser-profile` command in `~/.local/bin`.

The provisioning gate must name every profile that declares a browser cask.
`tests/browser-profiles.sh` derives that set from `profiles/`, so moving a
browser to another profile fails the suite until the gate is updated.

List the available contexts:

```bash
browser-profile list
```

Launch a context:

```bash
browser-profile open chrome personal
browser-profile open chrome work
browser-profile open firefox personal
browser-profile open firefox work
```

Add another lowercase context when a workflow needs stronger separation:

```bash
browser-profile add cloud-admin
browser-profile add security-testing
```

The command accepts lowercase letters, numbers, dots, underscores and hyphens.
It never removes profiles or edits browser-owned registries.

Each Chrome context uses a distinct `--user-data-dir`. Firefox uses a distinct
profile path with `-no-remote` so contexts can run concurrently. Firefox
instances launched this way do not receive links opened by other applications;
open or paste those links in the intended context manually.

Treat browser sync as crossing the isolation boundary. Do not sign personal,
work, administration and security-testing contexts into the same sync account
unless that sharing is deliberate. Review extensions, downloads, password
storage, client certificates and proxy settings independently in every context.

## macOS defaults

`script/macos-defaults` declares every setting once and drives application and
read-back from the same table, because macOS silently ignores keys it no longer
honours. Always work through the modes in order:

```bash
./script/macos-defaults --dry-run   # exact commands, nothing changes
./script/macos-defaults --diff      # current versus declared
./script/macos-defaults apply       # lists sudo commands, then confirms
./script/macos-defaults --verify    # read back; non-zero on drift
```

Restrict to one area while iterating:

```bash
./script/macos-defaults --diff --section security
```

`apply` records the previous value of every declared key under
`~/.config/security-ai-workstation/` before its first write, so changes can be
reversed.

Keys reported by `--verify` as mismatched after a successful `apply` are keys
this macOS version ignores. Record them in `TASKS.md`: the set changes between
releases and cannot be predicted from the repository.

Settings in the Safari domain are protected by TCC. They are reported as
unreadable unless the terminal has Full Disk Access, and this is a warning
rather than a failure.

## Commit signing

OpenPGP is the default method. Signing stays inactive until `gitSigningKey` is
set, so nothing changes until you supply a key.

Generate a key. Choose ed25519, set an expiry rather than "does not expire", and
use the same address as `user.email`:

```bash
gpg --full-generate-key
gpg --list-secret-keys --keyid-format=long
```

Take the long key ID from the `sec` line, after the algorithm and slash, then
record it in the chezmoi data and apply:

```bash
./bootstrap install --git-signing-key 0xYOURKEYID
# or, on an already-installed machine, edit gitSigningKey in
# ~/.config/chezmoi/chezmoi.toml and run ./script/setup
```

Publish the public key to the forge so signatures verify:

```bash
gpg --armor --export 0xYOURKEYID | gh gpg-key add --title "$(scutil --get ComputerName)" -
```

Or copy it to the clipboard and paste it into the forge's web UI instead:

```bash
gpg --armor --export 0xYOURKEYID | pbcopy
```

Verify end to end. The commit must report a good signature, not merely succeed:

```bash
git commit --allow-empty -m 'signing check'
git log --show-signature -1
```

`gpg-agent` prompts through `pinentry-mac` and can store the passphrase in the
Keychain. The cache is 30 minutes idle and 8 hours maximum, so an unattended
unlocked machine cannot sign indefinitely. If a commit fails with
`Inappropriate ioctl for device`, `GPG_TTY` is unset; `~/.zshrc` exports it, so
open a new shell.

Back up the secret key and a revocation certificate offline, alongside the
FileVault recovery key. Losing the secret key means every future commit needs a
new identity; losing the revocation certificate means a compromised key cannot
be retired.

To use a key held by 1Password, Secretive or a YubiKey resident key instead, set
`gitSigningMethod = "ssh"` and put the SSH public key in `gitSigningKey`. The
`allowedSignersFile` is generated only for that method.

## Backup

Selecting the `backup` profile installs `restic` and `rclone`. This supplements
encrypted Time Machine; it does not replace it. Nothing is scheduled
automatically.

Store the repository password in the password manager before creating the
repository. Losing it makes every backup unrecoverable.

```bash
rclone config                                   # configure the off-site backend
export RESTIC_REPOSITORY="rclone:remote:workstation"
restic init
```

Back up, then verify:

```bash
restic backup ~/workspace ~/Documents \
  --exclude-caches \
  --exclude '**/.venv' --exclude '**/node_modules' --exclude '**/target'
restic check --read-data-subset=5%
```

Run a restore drill into a scratch directory before relying on the repository,
and repeat it periodically. An untested backup is not a backup.

```bash
restic restore latest --target /tmp/restore-drill
```

Schedule with a launchd agent only after the manual workflow is proven, and keep
the agent under your own control rather than adding it to this repository.

## Short-lived cloud credentials

Selecting `cloud-aws` installs `granted` alongside the AWS CLI. Use it rather
than long-lived access keys, and never before running cloud scans.

```bash
granted sso populate --sso-region <region> <start-url>
assume <profile>            # issues a short-lived session
assume -c <profile>         # opens the console in an isolated browser profile
```

`granted`'s per-profile browser containers and the `browser-profile` contexts
serve the same purpose: keep administrative sessions out of the browser context
used for everything else.

## Package updates

Review before upgrading. `script/update-report` changes nothing:

```bash
./script/update-report
```

It reports declared-but-missing packages, everything with an update available,
and Homebrew's cleanup candidates. Upgrade deliberately, one package at a time:

```bash
brew upgrade <name>
```

Casks containing system extensions or kernel components deserve extra scrutiny,
because upgrading them changes privileged code.

Homebrew renames and deprecates tokens continuously. Check the declared set
against upstream before an install, and on a schedule from CI:

```bash
./script/check-tokens
```

## Recording machine state

```bash
./script/snapshot
```

Writes installed formulae, casks, taps and the macOS defaults read-back to a
timestamped file under `~/.config/security-ai-workstation/snapshots/`. The
repository declares intent; snapshots record what is actually present, which is
what an incident review needs.

## Package reconciliation

Removing an entry from a profile changes the declared state but does not
automatically uninstall the existing package. This separation prevents a
chezmoi apply from unexpectedly deleting applications or data.

Render the selected state:

```bash
./script/render-brewfile --output /tmp/workstation.Brewfile
```

Preview Homebrew's cleanup candidates:

```bash
brew bundle cleanup --file=/tmp/workstation.Brewfile
```

Review every candidate, its dependants, application data and replacement
workflow. Only after explicit approval should cleanup be executed:

```bash
brew bundle cleanup --force --file=/tmp/workstation.Brewfile
```

Do not add forced cleanup to bootstrap, chezmoi hooks or routine update
automation.

## Hardening and recovery

Run the audit; it exits non-zero under `--strict` so it can gate work:

```bash
./script/hardening-check --strict
```

It checks FileVault, SIP, Gatekeeper, Secure Boot policy, the application
firewall including logging, Remote Login, the guest account, automatic security
updates, loaded system and kernel extensions, Rosetta, and the declared macOS
defaults. Items requiring human judgement are reported for review and never
silently pass.

- Enable FileVault manually and store its recovery key offline.
- Maintain encrypted Time Machine and an off-site restic repository.
- Keep personal and work browser contexts separate; add cloud-administration
  and security-testing contexts only when required.
- Use short-lived, least-privilege cloud credentials.
- Review privacy permissions and background/login items after installing or
  removing security and productivity applications.

Chezmoi and bootstrap back up user-owned configuration before replacement where
the implementation supports it. Before recovering configuration, inspect Git
history and the timestamped backup rather than overwriting current state
blindly.
