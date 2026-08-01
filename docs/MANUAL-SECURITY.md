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

If you use one for SSH, `security-extra` provides `age-plugin-yubikey`, and
`docs/OPERATIONS.md` covers resident keys.

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

The application firewall and stealth mode are separate, and opt-in:

```bash
./bootstrap install --with-hardening
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

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
