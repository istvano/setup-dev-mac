# Operations

This runbook covers installation, application, verification, hardening and
package reconciliation. Architecture belongs in `ARCHITECTURE.md`; durable
rationale belongs in `DECISIONS.md`; unfinished work belongs in `TASKS.md`.

## Before first installation

1. Read the selected Brewfile fragments and all `chezmoi/run_*` scripts.
2. Run the static validation suite, requiring every check. Without the `REQUIRE_*`
   variables, five checks skip when their tool is absent and the suite still reports
   success — three of them printing "OK" as they do it:

   ```bash
   REQUIRE_LINTERS=1 REQUIRE_CHEZMOI=1 ./script/test
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
6. Rehearse the install in the disposable macOS VM, so the first run on real
   hardware is not the first run at all:

   ```bash
   ./script/install-tart && ./script/vm build && ./script/vm seal
   ./script/test-install
   ```

   See [Testing a real install](TESTING.md) and ADR-036. Note what the VM cannot
   prove on the machine you are using: nested virtualization needs M3 or later, so
   a container runtime cannot start in the guest on the M1 Pro build machine,
   though it can on the M5 Max target. `script/test-install` reports which case
   applies.
7. Decide where the FileVault recovery key will be stored offline.
8. Confirm Apple account recovery and two hardware security keys.

## Install

The interactive path is:

```bash
./bootstrap install
```

An explicit installation using the free defaults is:

```bash
./bootstrap install \
  --profiles core,dev,security,productivity,backup,kubernetes \
  --shell zsh \
  --runtime colima \
  --password-manager bitwarden \
  --firewall lulu \
  --git-name "Your Name" \
  --git-email "you@example.com"
```

The bootstrap validates Apple Silicon macOS, establishes the documented trust
set, writes the reviewed choices to chezmoi data and applies the source state.
It applies the declared macOS defaults and enables the application firewall with
stealth mode; both are reversible and both can be declined with
`--no-macos-defaults` and `--no-hardening`. It does not enable FileVault, install
Rosetta, modify Touch ID PAM, enable network services or install a major macOS
upgrade — those stay opt-in because each is either irreversible or can reboot.

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

`docs/MANUAL-SECURITY.md` covers the work that stays manual, with the reason and
a verification step for each item.

Also verify manually:

- The container substrate is present: `./script/container-substrate --verify`
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

Configurations created before the current data keys existed need `shell`,
`gitSigningMethod`, `gitSigningKey`, `workGitDir` and `workGitEmail` added to
`data` in `~/.config/chezmoi/chezmoi.toml`. `shell` is `zsh` or `fish`; it has no
default on purpose, so a stale configuration fails loudly in `./script/verify`
rather than being checked against a shell fragment nobody selected. `gitSigningMethod` is one of `gpg`,
`ssh` or `none`; an empty `gitSigningKey` disables signing regardless, and an
empty `workGitEmail` disables the work identity split.

If the data predates removal of the empty `ai` profile, remove `ai` from
`data.profiles`, along with the obsolete `syncNativeAi` and `pythonVersion`
keys; MLX and Python versions are entirely project-owned.

## Container substrate

Colima is the default runtime (ADR-037), and this section is about *using* containers
on the host. It is unrelated to testing the repository: `docs/TESTING.md` uses tart,
ssh and rsync, and neither `script/vm` nor `script/test-install` references Docker or
Colima at all. Do not start the substrate in order to run a VM test — it only competes
for memory.

The layer beneath project containers and clusters is declared rather than rebuilt by
hand:

```bash
./script/container-substrate --dry-run   # exact commands, nothing changes
./script/container-substrate             # create or reconcile; idempotent
./script/container-substrate --status
./script/container-substrate --verify    # non-zero when missing or drifted
```

It owns four things: the Colima VM, one Docker network on a pinned subnet, a shared
image registry and a persistent BuildKit builder. Nothing else — services with data
stay in the project that owns them, which is the boundary ADR-010 draws and ADR-037
refines.

**Nothing is started by `chezmoi apply`.** The VM commits 14 GiB of standing memory
and takes minutes to create, so hook 25 reports its state and names this command
instead. Sizing suits the 32 GB build machine; raise `SUBSTRATE_VM_MEMORY_GB` and
`SUBSTRATE_VM_CPUS` on the 128 GB target.

**Stop it when you are not using it.** The VM never gives memory back to macOS, so
14 GiB stays committed until `colima stop`. Measured on the build machine: running it
alongside a test guest put 22 GiB of 32 GB in use and 5 GB into swap. The network,
registry and build cache all survive a stop/start, so stopping costs only the ~10
second restart.

Sizing is compared against `colima list --json`, not assumed. An existing profile
keeps what it was created with: CPU and memory apply on the next start, but a disk
can only grow, so shrinking one means `colima delete` — which destroys every image,
volume and cluster in it.

Every published port binds `127.0.0.1`. A Docker port mapping without a host part
binds `0.0.0.0`, so `--port 5000` would put an unauthenticated image registry on
every network this laptop joins. Give cluster ports the same treatment in a project's
`k3d.yaml`: `127.0.0.1:8080:80`, not `8080:80`.

Clusters are project-owned. Keep a `k3d.yaml` in the project repository and point it
at the substrate:

```yaml
network: k3d-lan
registries:
  use:
    - k3d-shared-registry:5000
```

Pin the k3s image to the production minor version, and set non-default
`--cluster-cidr` and `--service-cidr` before creation — every k3s cluster otherwise
defaults to the same ranges, two clusters on one bridge then share an address space,
and CIDRs cannot be changed on a running cluster. Check for VPN collisions first with
`netstat -rn -f inet | grep '^10\.'`.

With ServiceLB kept, exactly one service per cluster can own ports 80 and 443. That
service is Traefik, and workloads are reached through Ingress — which is how
production works, so it is parity rather than a limitation. A second `LoadBalancer`
asking for port 80 stays `<pending>` by design.

### Migrating from Rancher Desktop

Rancher remains selectable, but two runtimes competing for the Docker socket is a
correctness problem before it is a performance one. Switch deliberately:

```bash
# 1. Stop Rancher and stop it starting again.
#    Quit the app, then System Settings > General > Login Items.

# 2. Re-select the runtime and re-apply.
sed -i '' 's/^runtime = "rancher"/runtime = "colima"/' ~/.config/chezmoi/chezmoi.toml
./script/setup

# 3. Confirm no second docker client remains on PATH.
exec zsh
which -a docker kubectl        # nothing under ~/.rd/bin

# 4. Create the substrate.
./script/container-substrate
```

Step 3 matters. The shell configuration only adds `~/.rd/bin` to `PATH` when Rancher
is the selected runtime, so re-applying removes the entry — but the directory and its
`docker` binary survive on disk until Rancher is uninstalled. Leave the cask
installed if a GUI fallback is wanted; just never run both at once.

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

## VS Code extensions

`vscode/extensions.list` is the declared state; every entry carries an exact
version. Applied automatically on `chezmoi apply` when the `dev` profile is
selected, and by hand with:

```bash
./script/vscode-extensions --dry-run   # print the commands, change nothing
./script/vscode-extensions apply
./script/vscode-extensions --diff      # installed versus declared
./script/vscode-extensions --verify    # non-zero on drift
./script/check-extensions              # network: are the pins still latest?
```

### Turn off VS Code's own extension updates

Pinning is defeated by VS Code updating extensions behind it. Set this in
`~/Library/Application Support/Code/User/settings.json`:

```json
"extensions.autoUpdate": false
```

The repository does not write this for you — `settings.json` is a personal file
and merging into it would be a destructive edit. `--verify` warns when the setting
is not `false` and reports the drift regardless, so a machine that ignores this
advice is noisy rather than silently wrong.

### Only roots are declared

Extension packs install their own children. `ms-python.python` brings Pylance,
the debugger and the environments extension; `ms-toolsai.jupyter` brings four
more; `ms-vscode-remote.remote-ssh` brings two; `ms-azuretools.vscode-docker`
depends on Container Tools. Those children are not declared and not pinned.

`--diff` resolves pack membership from each installed extension's own
`package.json`, so it separates three cases:

```text
== Declared but not installed at the declared version ==
== Installed but not declared ==            # things added by hand
== Arriving as a pack or dependency child ==
```

Nothing is ever uninstalled. An extension in the second list is left alone;
removing it is a decision, the same treatment `./script/update-report` gives
Homebrew cleanup candidates.

### Updating a pinned version

An extension update is new third-party code inside the editor, so it is reviewed
rather than applied automatically:

```bash
./script/check-extensions       # reports pinned versus latest for each entry
# edit vscode/extensions.list
./script/test
./script/vscode-extensions apply
```

## Fonts

`core` installs JetBrainsMono Nerd Font because `dot_config/ghostty/config`
selects it by name. An unknown font name is not an error in Ghostty — it falls
back silently, and the only symptom is prompt and `eza --icons` glyphs turning
into replacement boxes, so `tests/placement-policy.sh` asserts that the configured
font-family and the `core` cask stay paired.

The opt-in `fonts` profile adds more from
[ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts):

```bash
./bootstrap plan --profiles core,dev,security,productivity,backup,kubernetes,fonts
```

To use an unpatched font and still get every Nerd Font glyph, name the real font
first and the symbols-only font second — Ghostty tries them in order:

```text
font-family = Your Preferred Font
font-family = Symbols Nerd Font Mono
```

That second line requires the `fonts` profile, so add it only once
`font-symbols-only-nerd-font` is installed.

Fonts install to `~/Library/Fonts` per user. Confirm what the terminal actually
resolved rather than what was requested:

```bash
ghostty +show-config | grep font
ghostty +list-fonts | grep -i nerd
```

## Git diff and merge tools

Two tools, deliberately, for two different jobs. `delta` is `core.pager`, so
`git diff`, `git log -p` and `git show` stay in the terminal — the common case.
VS Code is registered as `diff.tool` and `merge.tool`, which only `git difftool`
and `git mergetool` invoke:

```bash
git difftool HEAD~1             # side-by-side
git difftool --dir-diff HEAD~1  # the whole changeset in one window
git mergetool                   # three-way editor, per conflicted file
```

`mergetool.keepBackup` is false, so a resolved conflict leaves no `.orig` file,
and `prompt` is false on both so they do not ask before launching each file.

The block is emitted only when `code` is on PATH at apply time, and records its
absolute path: a GUI Git client does not inherit the shell PATH. Neither tool
works over a plain SSH session, where `code --wait` has nothing to open.

`merge.conflictstyle` is `zdiff3`, so conflict markers include the common
ancestor. That is what makes a three-way merge readable whichever tool opens it.

## Interactive shell

`--shell` selects zsh (default) or fish. The choice is a mutually exclusive
Brewfile fragment, so fish replaces the two zsh plugin formulae rather than
adding to them:

```bash
./bootstrap plan --shell fish
```

On an already-installed machine, edit `shell` in
`~/.config/chezmoi/chezmoi.toml` and run `./script/setup`. Chezmoi then installs
the other fragment, writes or removes `~/.config/fish`, and re-renders the
Ghostty configuration.

### The login shell is not changed

Selecting fish configures Ghostty to run it (`command = <brew prefix>/bin/fish
--login`, resolved at apply time). The account login shell stays zsh,
deliberately:

- A fish configuration that fails to parse costs a terminal tab, not the ability
  to log in.
- `chsh` requires editing `/etc/shells` with sudo. Privileged, hard-to-reverse
  account changes stay manual here, like FileVault and the Touch ID PAM entry.
- Anything reading `$SHELL` — `git`, editors, `ssh <host> <command>` — keeps
  getting a shell that is always present on macOS.

`--login` is not cosmetic. fish applies `/etc/paths` and `/etc/paths.d` only when
it is a login shell, and those are how macOS installers put themselves on `PATH`.
Without it fish starts normally and quietly has a shorter `PATH` than zsh.

Every apply reports the current state and changes nothing:

```text
[INFO] Login shell is /bin/zsh; the selected interactive shell is fish.
```

To change it anyway, both steps are required, because `chsh` refuses a shell that
is not listed in `/etc/shells`:

```bash
echo "$(brew --prefix)/bin/fish" | sudo tee -a /etc/shells
chsh -s "$(brew --prefix)/bin/fish"
```

Reverse it with `chsh -s /bin/zsh`. Keep a second terminal open until a new
window has started successfully.

### Verifying the shell configuration

Upstream resolvers report effective values after parsing (ADR-030):

```bash
ghostty +show-config | grep -E 'shell-integration|^command'
dscl . -read "/Users/$USER" UserShell   # the login shell, not $SHELL
fish -n ~/.config/fish/config.fish      # parse without executing
fish -c 'echo $fish_key_bindings'       # must be fish_default_key_bindings
bind ctrl-w                             # backward-kill-path-component
starship explain                        # same prompt modules under either shell
```

`$SHELL` names the shell that happens to be running, so it cannot confirm either
the selection or the login shell.

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

## Lab virtual machines

The `lab` profile provides the isolated Linux VM that `docs/ARCHITECTURE.md`
names as an execution domain. Anything hostile, kernel-sensitive or
architecture-specific belongs here rather than on the host or in a container:
exploit development, malware analysis, untrusted binaries, ptrace and GDB work.

Lima handles the common case — scriptable, disposable, declared in YAML:

```bash
limactl start --name=lab template://ubuntu-lts
limactl shell lab
limactl stop lab && limactl delete lab      # disposable by design
```

Reach for UTM when Lima cannot help: a GUI is needed, a non-Linux guest is
involved, or the work is **x86-specific**. Lima runs arm64 guests under
Virtualization.framework, so x86_64 emulation is UTM's job, and it is slow
enough that it should be a deliberate choice rather than a default.

Provision with Ansible over SSH rather than by hand, so a compromised or broken
lab VM can be destroyed and rebuilt instead of repaired:

```bash
ansible -i lab, -m ping all
ansible-playbook -i lab, lab.yml
```

Two rules make the boundary real rather than nominal:

- Do not mount the home directory, SSH directory or credential stores into a lab
  VM. Share a single scratch directory if something must cross.
- Snapshot before running anything untrusted, and revert afterwards. A VM you
  keep patching is no longer isolated from what it has run.

## Intercepting proxies

`security-extra` installs Burp Suite and mitmproxy. Both read HTTPS by
terminating TLS, which requires a root CA in the keychain. While that
certificate is trusted, anything holding its private key can decrypt every TLS
session the machine makes — not only the traffic being debugged.

Changing interception tool does not change this: the root CA is inherent to the
technique, not to any one implementation. What it changes is who maintains the
code holding that privilege, which is why mitmproxy is preferred here.

Treat the CA as a temporary grant, not a setup step:

```bash
# Confirm what is currently trusted before and after a debugging session.
security dump-trust-settings -d 2>/dev/null | grep -iE 'rockxy|portswigger|burp'
```

Remove the certificate from the login and System keychains when the session
ends, and re-add it next time. Leave system-wide proxy settings off when not in
use; a proxy left configured silently routes traffic through a stopped listener
or, worse, a running one.

mitmproxy runs three ways from one install: `mitmproxy` (terminal UI),
`mitmweb` (browser UI) and `mitmdump` (scriptable, non-interactive). Its CA is
generated on first run into `~/.mitmproxy`; trust it deliberately and remove it
afterwards.

```bash
mitmproxy --listen-host 127.0.0.1 --listen-port 8080
```

Bind to `127.0.0.1` explicitly. mitmproxy listens on all interfaces by default,
which would turn the machine into an open proxy on any network it joins.

## MCP servers

An MCP server is arbitrary code with tool access to this machine. The default
way to run one, `npx -y package@latest`, fetches and executes unpinned remote
code every time an agent starts. Two controls apply instead (ADR-029): an
approved catalogue that Claude Code enforces, and container isolation that
applies to every agent.

### Install the policy

```bash
./script/mcp-policy --dry-run    # the exact privileged commands
./script/mcp-policy --diff       # installed versus declared
./script/mcp-policy apply        # confirms before writing the system path
./script/mcp-policy --verify     # non-zero on drift
```

`script/hardening-check` runs `--verify`, so a drifted or missing policy fails
the audit.

Prove it is in force. The second command must be refused by policy before
anything is contacted, so the URL does not need to be real:

```bash
claude mcp list
claude mcp add --transport http test https://example.com/mcp
```

### Add a server

1. **Inspect it before trusting it.** `mcp-inspector` shows the tools it
   actually exposes, which is often broader than its README suggests:

   ```bash
   npx @modelcontextprotocol/inspector npx -y <package>@<version>
   ```

2. **Pin it.** Resolve the version; never `@latest`.
3. **Allowlist it** in `mcp/managed-settings.json`. Which key depends on how it
   runs: a direct stdio server uses `serverCommand` with the exact pinned
   command; a ToolHive-managed server uses `serverUrl` with its fixed loopback
   port. Never `serverName` — it is a label the user assigns, so any server can
   claim it. `tests/mcp-policy.sh` rejects an unpinned spec, a `serverName`
   allowlist entry and a wildcard loopback port.
4. **Apply and verify**, then restart the agent.

Because `serverCommand` matches every argument in order, the pinned command is
the only form that will load. A bumped version is a deliberate edit to a file
that is reviewed in git.

### Optional: run servers in containers with ToolHive

ToolHive is **not installed by default and nothing depends on it**. The policy
above works without it. Install it when a server is not fully trusted, needs
credentials, or came from someone else — it is the only control that limits what
a server can reach once loaded, and the only one that applies to Codex and
opencode as well as Claude Code.

Without it, a server runs as your user, with your environment, your credentials
and your network access. The allowlist decides *which* servers load in Claude
Code; it does not constrain them afterwards.

ToolHive does not run servers as stdio commands. It runs each one in its own
container and exposes it over HTTP on loopback, so the allowlist entry is a
**`serverUrl`, not a `serverCommand`**.

It also assigns a random proxy port unless told otherwise. A random port cannot
be pinned, and the only allowlist entry that would match it is a wildcard like
`http://127.0.0.1:*/*` — which permits any process listening on loopback to load
as an MCP server. Always fix the port; `tests/mcp-policy.sh` rejects a wildcard
loopback port for this reason.

Start the container runtime first, then:

```bash
./script/install-toolhive          # pinned release, verified against the lock file
thv run --proxy-port 8123 \
        --isolate-network \
        --permission-profile none \
        <server>
thv list                           # shows each server and its URL
```

`--isolate-network` cuts the container off from the host network and
`--permission-profile none` grants nothing by default; widen only what a
specific server demonstrably needs.

Order matters. `allowManagedMcpServersOnly` is true, so a server that is not on
the allowlist will not load even after ToolHive registers it:

```bash
# 1. add {"serverUrl": "http://127.0.0.1:8123/mcp"} to mcp/managed-settings.json
./script/mcp-policy apply          # 2. policy first
thv client register claude-code    # 3. then point the client at the URL
                                   # 4. restart the agent
claude mcp list                    # 5. confirm it loaded
```

Use `127.0.0.1`, not `localhost`: allowlist URLs match the literal host, so a
`localhost` pattern will not match a `127.0.0.1` URL.

Pass credentials with `--secret`, which pulls from ToolHive's secrets manager
into the container's environment. Never put them in the policy file or a client
config, both of which any user on the machine can read.

### What pinning means under ToolHive

With a direct stdio server, the allowlist pins the exact package and version.
With ToolHive, the allowlist pins a loopback URL, and the version pinning moves
into the container image ToolHive runs. That is a deliberate trade: the
allowlist becomes less specific, and in exchange the server holds no host
credentials and cannot reach the host network. Review the image reference
ToolHive resolves with `thv list` and treat it as you would any other image
under ADR-006.

`thv` is deliberately outside Homebrew, so `brew upgrade` will not move it.
`./script/update-report` reports when a newer release exists; bumping means
editing `mcp/toolhive.lock` with the published digests and re-running the
installer.

### What is not enforced

Only Claude Code enforces the allowlist. Codex and opencode read their own
configuration, and no equivalent mechanism could be confirmed for either, so
review those two by hand after adding any server.

Container isolation is the only control covering all three, and it is optional,
so by default the enforced surface is one agent. Weigh that when adding a server
you did not write.

## Local AI models

Two separate things, with different placements.

### MLX: project-local, nothing installed on the host

MLX is a Python dependency, not a workstation package (ADR-004). Nothing is
installed globally, and `tests/placement-policy.sh` fails the suite if an `mlx`
token appears in any profile. Everything MLX needs is already present: `uv` from
`core`, the Xcode Command Line Tools from the bootstrap, and Apple Silicon.

Per project:

```bash
uv init
uv add mlx mlx-lm
```

Add `mlx-vlm`, notebooks and serving dependencies only to the projects that use
them. A development server must bind to loopback and must not be presented as
production-safe.

There is no `huggingface-cli` Homebrew formula. The CLI ships inside the
`huggingface_hub` package, so install it as an isolated uv tool rather than
adding it to a profile:

```bash
uv tool install "huggingface_hub[cli]"
hf download mlx-community/<model> --local-dir ./models/<model>
```

Crawl4AI is the same shape: a Python crawler for LLM pipelines, with no Homebrew
package. It belongs in the project that uses it, or as an isolated tool, never in
a profile (ADR-004):

```bash
uv add crawl4ai            # in the project that needs it
uv tool install crawl4ai   # or standalone, isolated from every project
```

Crawling fetches and renders untrusted pages. Treat it as a network-facing
dependency: pin the version in the project, and prefer running it in that
project's container when a run is unattended or scheduled.

### LM Studio: opt-in `local-llm` profile

```bash
./bootstrap plan --profiles core,dev,security,productivity,local-llm
```

Operating constraints, all of which differ from the rest of the workstation:

- **It updates itself.** The cask carries `auto_updates`, so new versions arrive
  without `brew upgrade` and without appearing in `./script/update-report`.
  Treat it as outside the reviewed update flow and read its release notes.
- **Keep the server on loopback.** The OpenAI-compatible server defaults to
  `localhost:1234`. Leave "Serve on Local Network" off; enabling it exposes an
  unauthenticated inference endpoint to the network.
- **The weights are the trust surface, not the app.** Prefer GGUF and
  safetensors. Avoid pickle-backed `.bin` checkpoints, which execute code when
  loaded. Model publishers are as much a supply-chain dependency as any package.

### Model storage and backup

Weights are large and re-downloadable, so they do not belong in an off-site
backup. LM Studio stores under `~/.lmstudio`, and Hugging Face caches under
`~/.cache/huggingface`. Exclude both from restic:

```bash
restic backup ~/workspace ~/Documents \
  --exclude-caches \
  --exclude "$HOME/.lmstudio" \
  --exclude "$HOME/.cache/huggingface" \
  --exclude '**/.venv' --exclude '**/node_modules' --exclude '**/target'
```

Keep a note of which models a project depends on in that project's own
repository. That is the reproducible artefact; the weights themselves are not.

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
  --exclude "$HOME/.lmstudio" \
  --exclude "$HOME/.cache/huggingface" \
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

## Kubernetes and GitOps

The `kubernetes` profile is client-side only; no cluster runs on the host unless
`kind` is started deliberately.

```bash
kubectx                      # choose a cluster, then confirm it before acting
kubeconform -strict -summary manifests/     # schema check, no cluster needed
kustomize build overlays/prod | kubeconform -strict -
helmfile diff                # what a release change would do
argocd app diff <app>        # what the cluster and Git disagree about
```

Diff before sync, always. `argocd app sync` against the wrong context is the
failure mode these tools exist to prevent, and `kubectx` makes the current
context cheap to check.

Commit secrets only as SealedSecrets:

```bash
kubeseal --controller-namespace kube-system <secret.yaml >sealed-secret.yaml
```

The sealed output is safe to commit; the input is not. Keep the plaintext out of
the repository entirely — `gitleaks` runs in `./script/test`, but do not rely on
a scanner to catch what should never have been staged.

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
