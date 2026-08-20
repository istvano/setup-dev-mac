# Manual security work

Everything here is deliberately **not** automated. Each item either needs a
decision only you can make, destroys data if applied blindly, requires a physical
action, or lives behind a macOS consent dialog that no script may click.

Work through it in your own order and apply what fits. Nothing here is required
for the workstation to function, and skipping an item is a valid choice as long
as it is a chosen one.

Check what is already done with `./script/hardening-check`, which reports each
item as pass, fail or review and exits non-zero under `--strict`.

---

## 1. FileVault, and the recovery key

Full-disk encryption. Without it, every other control on this list protects a
disk that can be read by removing it.

```bash
fdesetup status            # check
sudo fdesetup enable       # enable; prints a recovery key ONCE
```

**Not automated because** enabling it produces a recovery key that must leave the
machine, and a script cannot verify you stored it. A key lost with the machine is
the same as no key.

**Store the recovery key offline** — on paper, or in a password manager on a
different device. Not in this repository, not in a note on the same Mac, not in a
screenshot.

Verify: `fdesetup status` reports `FileVault is On.`

---

## 2. Remote services

Every enabled sharing service is a listening port.

```bash
sudo systemsetup -getremotelogin                      # SSH
sudo launchctl list | grep -i -E 'screensharing|ard'  # Screen Sharing, Remote Management
```

Turn off what you do not use, in **System Settings → General → Sharing**.

**Not automated because** disabling Remote Login on a machine you administer over
SSH disconnects you, possibly permanently if there is no console. The repository
never enables a network service, and it will not disable one either.

If you keep Remote Login on, restrict it: key-only authentication, and limit
which users may connect.

---

## 3. Hardware security keys

A YubiKey or equivalent for SSH, commit signing, and as a second factor on the
accounts that matter — the forge, the cloud providers, the password manager.

**Not automated because** it requires physical possession, and enrolment is a
per-service flow.

Register **two** keys everywhere. One key is a single point of failure: lose it
and you lose the accounts it protects.

**No hardware-key tooling is installed by any profile.** `ykman`, `age-plugin-yubikey` and
Secretive are all present in `profiles/security-extra.Brewfile` as commented-out lines —
evaluated and left off, so selecting that profile gives you none of them. Install what you
need by hand, and note the division: `age-plugin-yubikey` backs **age and SOPS** identities,
not SSH. For SSH resident keys see `docs/OPERATIONS.md`; for a Secure-Enclave SSH key,
Secretive is the commented-out candidate, and commit signing with it works because
`user.signingkey` is emitted with a `key::` prefix (ADR-042 discussion in
`chezmoi/dot_gitconfig.tmpl`).

---

## 3a. Identity: the age key and the per-machine SSH key

**Verify with** `./script/identity --check`. On a freshly installed machine this is the one
check that will fail, so it belongs here rather than being a surprise.

**Not automated because** the age key has to come out of a vault only you can unlock, and
the SSH public key has to be enrolled at services only you can log into.

The two halves are treated differently on purpose:

- **The age key is restored**, from a Bitwarden item named `age-identity` (override with
  `AGE_BW_ITEM`). It has to be: files encrypted to an identity you no longer hold cannot be
  read, so a second identity is data loss. When the vault is locked during install — which
  is the normal case, since the hook has no terminal — a fresh key is minted and
  `~/.config/age/.locally-generated` is left behind. `--check` reports that as a **failure**
  until you either restore the right key with `./script/identity --restore` or store the
  generated one and delete the marker.
- **The SSH key is generated per machine** and never moved, because a signing key is simply
  enrolled again. Read it back with `cat ~/.ssh/id_ed25519.pub`, enrol it, and revoke the
  old machine's key when you decommission it. It has no passphrase, so FileVault is what
  protects it at rest; add one with `ssh-keygen -p -f ~/.ssh/id_ed25519` if you prefer.

### Creating the `age-identity` item

Once per identity, not once per machine. Every later Mac restores from this item, so the
name and the field both matter.

**The secret must be in the Notes field.** `script/identity --restore` and the install hook
both read it with `bw get notes age-identity`, which returns *only* the notes. A key pasted
into a Login item's password field, or into a custom field, leaves the restore failing with
"does not contain an age secret key" — the item exists, the vault is unlocked, and it still
does not work. A Secure Note is the natural type, though any type with the key in its notes
is read correctly.

1. In the Bitwarden app or web vault: **New item → Secure note**, named `age-identity`.
   Keep the name unique in the vault: `bw get` fails outright when a search matches more
   than one item.
2. Paste the **entire** contents of `~/.config/age/keys.txt`, comment lines included. That
   file as `age-keygen` writes it *is* the identity file — age reads the `#` lines as
   comments — and keeping the `# public key:` line lets you identify which key this is
   without decrypting anything.
3. Save, then run `bw sync`. The CLI works from a local cache and does not see an item
   created in the GUI until it syncs, which looks exactly like the item not existing.

Then prove the round trip, before you rely on it:

```bash
export BW_SESSION="$(bw unlock --raw)"
bw sync
XDG_CONFIG_HOME="$(mktemp -d)" ./script/identity --restore
```

`AGE_DIR` is derived from `XDG_CONFIG_HOME`, so this restores into a throwaway directory
and cannot overwrite the real key. The public key it prints must match the `# public key:`
line in your own `keys.txt`. Only once that matches, clear the marker on this machine and
re-check:

```bash
rm ~/.config/age/.locally-generated
./script/identity --check
```

**If you selected 1Password** rather than Bitwarden, no SSH key is generated at all — the
keys live in 1Password's agent and the hook is skipped deliberately. `--check` will still
say "No SSH key … It is generated by chezmoi apply", which is wrong for that selection.
Confirm the agent is enabled in 1Password instead.

The full ordered procedure for a new machine is in [New machine](NEW-MACHINE.md).

---

## 4. Privacy permissions (TCC)

macOS gates the powerful capabilities behind consent dialogs. Review who holds
them, in **System Settings → Privacy & Security**:

- **Full Disk Access** — the widest grant on the system. Terminal emulators are
  often here; consider whether they need it.
- **Accessibility** — allows synthetic input and reading other apps' UI. Window
  managers and automation tools ask for it.
- **Screen Recording** — screenshot and capture tools.
- **Input Monitoring** — reads keystrokes regardless of focus.
- **Developer Tools** — exempts a process from some protections.

**Not automated because** the TCC database is protected precisely so that no
script can grant itself these. That is a feature.

Grant nothing you cannot name a reason for, and re-check after installing
anything that asks. An app that stops working when you deny it is telling you
something useful.

---

## 5. BetterDisplay permissions

`productivity` installs BetterDisplay, which needs permissions to do DDC input
switching — the reason it is a hard requirement here rather than a convenience
(ADR-007).

Grant what it asks for and confirm input switching actually moves the monitors
between machines. If it does not, the permission is missing rather than the
feature being broken.

---

## 6. Browser isolation

`productivity-extra` provisions separate `personal` and `work` data roots for
Chrome and Firefox (ADR-014):

```bash
browser-profile list
browser-profile chrome work
```

**Decide deliberately about sync.** Signing two contexts into the same browser
account merges history, extensions and passwords, which defeats the separation
the profiles exist to create. The repository provisions the roots and takes no
position on which accounts you use in them.

---

## 7. Touch ID for sudo

Opt-in, and only through `/etc/pam.d/sudo_local`, which survives macOS updates:

```bash
./bootstrap install --with-touchid-sudo    # or copy the template by hand
```

**Not automated because** it changes an authentication path. It is convenience,
not security: it makes sudo easier, not harder to abuse.

---

## 8. Backups: restic and Time Machine

`backup` installs `restic` and `rclone`; neither is configured, and no schedule
is created.

```bash
restic init --repo <destination>
restic backup ~/…
restic restore latest --target /tmp/restore-drill   # actually do this
```

**Run a restore drill.** A backup that has never been restored is a hypothesis.

Use an encrypted Time Machine volume alongside it for the local-and-fast case.
The two answer different questions: Time Machine for "I deleted a file", restic
for "the machine is gone".

---

## 9. Outbound firewall

`lulu` or `little-snitch` is installed but starts with no rules. It is only
useful once you have taught it what normal looks like, which takes a few days of
answering prompts.

The application firewall and stealth mode are separate from LuLu, and are enabled
by default. Verify, or decline them:

```bash
./bootstrap install                     # firewall and stealth mode on
./bootstrap install --no-hardening      # leave the firewall untouched
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

Stealth mode stops the machine answering `ping` and other unsolicited probes, so
a host that has gone quiet on the network is the expected result, not a fault.

**Careful over SSH.** Enabling these can end a remote session.

---

## 10. macOS defaults

Not security-critical, but part of the same review:

```bash
./script/macos-defaults --diff      # current versus declared
./script/macos-defaults apply
./script/macos-defaults --verify    # which keys this macOS accepted
```

Record the keys `--verify` reports as drifted — those are the ones this macOS
version silently ignores, and the list is version-specific.

## 11. Editor telemetry

ADR-046 opts this workstation out of telemetry wherever it can be done from a
file this repository owns. Two editors cannot be, because
`vscode/README.md` states the boundary: *"The scripts do not edit `settings.json`
— that file is yours."* Owning the telemetry key would mean owning the file, so
these two are yours to set.

Both ship with telemetry **on**.

**VS Code.** Settings → search `telemetry` → *Telemetry Level* → `off`, or in
`settings.json`:

```json
"telemetry.telemetryLevel": "off"
```

`off` is the only value that also stops crash reports; `error` and `crash` still
send. Verified against code.visualstudio.com/docs/configure/telemetry.

**Zed.** `~/.config/zed/settings.json`:

```json
"telemetry": { "diagnostics": false, "metrics": false }
```

Both keys are needed — `diagnostics` covers crash reports and `metrics` covers
usage. Verified against Zed's own `docs/src/telemetry.md`.

**OpenHands**, if you run it, carries a PostHog key baked into the image, so its
web UI reports usage until told otherwise in its settings. There is no file this
repository can set for a value compiled into someone else's container.

Everything else is handled: the shell configuration exports the four verified
variables, and chezmoi hook 31 sets the three that need a command. See ADR-046
for what was checked and what could not be.
