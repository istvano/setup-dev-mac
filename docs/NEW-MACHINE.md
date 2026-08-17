# Setting up a new Mac

An ordered runbook from a machine out of its box to a working development environment.
Follow it top to bottom. Everything that cannot be automated is called out with **Manual**,
so nothing is discovered halfway through.

Every other document in `docs/` assumes you already have a checkout and a configured
machine. This one does not assume anything.

---

## 0. Before you wipe the old Mac

Do this **first**. Software is reproducible from this repository; identity is not. Once the
old machine is gone, anything in this list is gone with it.

- [ ] **Confirm the age key is in Bitwarden.** `cat ~/.config/age/keys.txt` on the old Mac
      and check the same value is stored in the vault. Without it, every SOPS-encrypted file
      you own becomes permanently unreadable — nothing in this repository can recover it.
- [ ] **Export the GPG secret key, ownertrust and a revocation certificate**, if you sign
      with GPG. See [Operations](OPERATIONS.md).
- [ ] **Note which SSH public keys are enrolled** at GitHub and at work. The new Mac gets its
      own key, so the old one should be *removed* from those services once you are done.
- [ ] **Export LuLu / Little Snitch rules** if you want to keep the answers you built up.
- [ ] **Copy `~/.config/chezmoi/chezmoi.toml`** somewhere safe. It records every choice you
      made — profiles, shell, runtime, identity — and re-answering from memory is the most
      annoying avoidable part of a rebuild.
- [ ] Check that anything you care about outside `$HOME` is in a backup.

---

## 1. macOS first boot

**Manual.** Work through Setup Assistant: create the account, sign in to your Apple Account,
join Wi-Fi. Decline the migration assistant — this repository is the migration.

Then open **Terminal** (the built-in one; Ghostty arrives later).

---

## 2. Get the repository

The repository is public, so this needs no authentication and no SSH key — which matters,
because on a brand-new Mac you do not have one yet.

```bash
mkdir -p ~/workspace/istvano
git clone https://github.com/istvano/setup-dev-mac.git ~/workspace/istvano/setup-dev-mac
cd ~/workspace/istvano/setup-dev-mac
```

**Accept the Command Line Tools dialog if it appears.** macOS ships a `git` stub that
triggers that installer the first time you run `git`, and you need git for the clone above —
so cancelling it leaves you with no repository and nothing to run in step 3. (`./bootstrap`
can install the tools itself, headlessly, but only from a checkout you already have.)

If you would rather not wait for the GUI installer, download a snapshot instead and let
`./bootstrap` fetch the tools:

```bash
mkdir -p ~/workspace/istvano && cd ~/workspace/istvano
curl -fsSL -o setup-dev-mac.tar.gz \
  https://github.com/istvano/setup-dev-mac/archive/refs/heads/main.tar.gz
tar -xzf setup-dev-mac.tar.gz && mv setup-dev-mac-main setup-dev-mac
cd setup-dev-mac
```

A tarball has no `.git`, so replace it with a real clone once the tools are installed —
`./script/test` needs the history for its secret scan.

> **Choose this location deliberately.** `./bootstrap` records the checkout path as
> `sourceDir` in `~/.config/chezmoi/chezmoi.toml`. Moving the directory afterwards breaks
> every `chezmoi apply` with a confusing error. Put it where it will stay.

---

## 3. Review, then install

```bash
./bootstrap plan          # prints the full selection, changes nothing
./bootstrap install
```

`plan` is worth reading. It shows every profile, the container runtime, the password
manager, the firewall, and whether macOS defaults and hardening will be applied. The install
takes roughly 30–45 minutes on a fast connection.

What it does, in order: installs the Command Line Tools (using `softwareupdate`, so no GUI
detour), installs Homebrew after showing you the installer's SHA-256 and asking twice,
installs the bootstrap trust set, asks for your git identity, enables the application
firewall, then hands over to chezmoi to apply the dotfiles and install every declared
package.

Two of those steps download outside Homebrew, so they are worth recognising rather than
wondering about. chezmoi installs **tart**, the VM engine the test harness runs on, by
fetching the release pinned in `vm/tart.lock` and checking its SHA-256 and Apple Team
Identifier before installing — it is not a Homebrew package, because that would need a tap
(ADR-020). With the `kubernetes` profile it also installs six **kubectl plugins** through
krew into `~/.krew/bin`. Neither is fatal: if GitHub is unreachable, the install reports it
and carries on, and the retry command is printed.

**You will be asked for your password more than once**, and one of those prompts arrives
well into the package installation rather than at the start. That is expected.

**Manual, during the run:** several casks are installed by Apple's installer and ask for an
administrator password in their own dialog — LuLu and Bitwarden among them. Note that these
prompts echo in cleartext if you are recording the session with `script`; see
[Security](../SECURITY.md).

---

## 4. Identity

This is the part that is not just software, and this document is the only place it is
written down — `docs/OPERATIONS.md` covers GPG key generation but says nothing about
`script/identity`, the age key or the Bitwarden restore. Do not skip ahead expecting to
find the detail there.

Two things behave differently on purpose:

- **The age key is restored** from Bitwarden, because files encrypted to an identity you no
  longer hold cannot be read. A second identity is data loss, not an inconvenience.
- **SSH keys are generated per machine** and never moved, because a signing key is simply
  enrolled again. One public key per Mac means losing a Mac is one revocation.

If you selected **1Password** rather than Bitwarden, no SSH key is generated at all: the
keys live in 1Password's agent, so the hook is skipped deliberately. `./script/identity
--check` will still report "No SSH key … It is generated by chezmoi apply", which is wrong
advice for that selection — ignore it and confirm the agent is enabled instead.

- [ ] **Sign in to Bitwarden.** Two separate things, and the second is easy to miss: sign
      into the desktop app, *and* authenticate the CLI, which keeps its own credentials:

      ```bash
      bw login          # once per machine; asks for email, master password and 2FA
      bw status         # should report "locked" or "unlocked", not "unauthenticated"
      ```

      Without `bw login`, `bw status` reports `unauthenticated` and `bw unlock` below answers
      `You are not logged in.` — clear enough, but only if you know the CLI is a separate
      login from the app.
- [ ] **Restore the age key.** Expect the install to have *generated* a local one rather
      than restoring it: the hook can only read the vault if `bw` is already unlocked, and
      it runs without a terminal, so on a first run it almost always mints. That is why it
      leaves a marker and why `./script/identity --check` reports a **failure** until the
      key is the right one. Fix it now:

      ```bash
      export BW_SESSION="$(bw unlock --raw)"
      ./script/identity --restore
      ```

      If this Mac is replacing another, do this **before encrypting anything**. A second
      identity does not merely inconvenience you — files encrypted to the old key cannot be
      read with the new one.

      If this is genuinely your first machine, keep the generated key: store it in Bitwarden
      as a secure note named `age-identity`, then delete
      `~/.config/age/.locally-generated` so the check passes.
- [ ] **An SSH key is generated for this machine** and never leaves it. Each Mac has its own,
      which is the point: losing one machine means revoking one key.

      The apply prints the public key, but that scrolls past during a 30–45 minute install,
      so read it back rather than hunting for it:

      ```bash
      cat ~/.ssh/id_ed25519.pub          # the value to paste
      ssh-keygen -lf ~/.ssh/id_ed25519.pub   # the fingerprint GitHub shows next to it
      ```

      Enrol it at <https://github.com/settings/ssh/new> and at work. Note that
      `./script/identity --check` prints only the fingerprint, not the key itself.
- [ ] **Switch this checkout to SSH** once the key is enrolled, so pushes work:
      ```bash
      git remote set-url origin git@github.com:istvano/setup-dev-mac.git
      ```
- [ ] **Import GPG material** if you sign with GPG.

---

## 5. Manual steps macOS will not let a script do

None of these can be automated on a Mac that is not under MDM. The permission database is
protected, and Screen Recording cannot be pre-granted even with a configuration profile.

- [ ] **Approve LuLu's system extension**: System Settings → Privacy & Security → Allow.
      Until you do, the outbound firewall is installed but not running.
- [ ] **Grant Full Disk Access** to your terminal, or some macOS defaults read as unset when
      they are merely unreadable.
- [ ] **Grant Accessibility / Screen Recording** to anything that needs them, when it asks.
- [ ] **Enable FileVault** and store the recovery key somewhere that is not this machine.
      See [Manual security](MANUAL-SECURITY.md).
- [ ] **Sign in to the App Store**, if you use it.
- [ ] **Enter licence keys** for anything from the `paid` profile.
- [ ] **Set the machine name**, since the configuration records it and templates can vary
      on it: `sudo scutil --set ComputerName <name>`. Do this *before* installing. Changing it
      afterwards needs `chezmoi init --source <repo>` to re-render the config — `./script/setup`
      will **not** pick it up, because it only runs `chezmoi diff` and `chezmoi apply`, and
      neither re-reads the config template. `machineName` is
      then available to any template as `{{ .machineName }}`, and the container substrate
      sizes the Colima VM from this machine's actual memory and core count rather than from
      a constant — so nothing needs adjusting by hand on a larger Mac.

---

## 6. Verify

```bash
./script/verify            # declared state installed, chezmoi healthy
./script/identity --check  # age key, SSH key, signing
./script/hardening-check   # security posture; --strict to make failures fatal
```

A fresh machine is expected to fail the FileVault check until you enable it, and the MCP
policy check until you run `just mcp-policy`.

---

## 7. Optional, when you need them

- **The container substrate** — `just substrate` creates the Colima VM, shared network and
  registry. It is a standing memory cost, so it is deliberately not part of the install.
- **The MCP policy** — `just mcp-policy` installs the allowlist to `/Library`. Read
  [`mcp/README.md`](../mcp/README.md) first: it governs which MCP servers may run at all.
- **Backups** — `restic` and `rclone` are installed but no repository exists yet.

---

## If something goes wrong

`./bootstrap plan` changes nothing and is always safe to re-run. `./script/verify` reports
what is missing without fixing it. The install is idempotent: running `./bootstrap install`
again after a failure picks up where it left off rather than starting over.
