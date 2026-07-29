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

If the chezmoi data predates removal of the empty `ai` workstation profile,
remove `ai` from `data.profiles` before the next apply. The obsolete
`syncNativeAi` and `pythonVersion` data keys can also be removed; MLX and Python
versions are now entirely project-owned.

Configurations created before the minimal-profile redesign should also review
`data.profiles`. The new default is `core`, `dev`, `security` and
`productivity`; cloud providers, Kubernetes, data tools, privileged security
monitors and personal productivity applications now require their explicit
profile names.

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

## Browser profiles

Selecting `productivity-extra` installs Chrome and Firefox Developer Edition.
Chezmoi then creates private `personal` and `work` data roots for both browsers
and installs the `browser-profile` command in `~/.local/bin`.

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

- Enable FileVault manually and store its recovery key offline.
- Maintain encrypted Time Machine and off-site backups.
- Keep personal and work browser contexts separate; add cloud-administration
  and security-testing contexts only when required.
- Use short-lived, least-privilege cloud credentials.
- Review privacy permissions and background/login items after installing or
  removing security and productivity applications.

Chezmoi and bootstrap back up user-owned configuration before replacement where
the implementation supports it. Before recovering configuration, inspect Git
history and the timestamped backup rather than overwriting current state
blindly.
