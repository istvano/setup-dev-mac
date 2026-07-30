# VS Code extensions

`extensions.list` is the declared state. `script/vscode-extensions` applies it,
and a chezmoi hook runs that on apply when the `dev` profile is selected —
`dev` is what installs VS Code.

```bash
just extensions          # install the declared versions
just extensions-diff     # installed versus declared
just extensions-verify   # non-zero on drift
just extensions-check    # network: are the pins still the latest published?
```

## Why the list looks the way it does

**Exact versions, never latest.** An extension is unreviewed third-party code
running inside the editor with the editor's filesystem access — the same trust
problem as an MCP server package, so it gets the same answer as ADR-029. See
ADR-032.

**Only roots are declared.** An extension pack installs its children
automatically. Declaring `ms-python.python` brings Pylance, the debugger and the
environments extension; `ms-toolsai.jupyter` brings four more; `remote-ssh`
brings two. Pinning a child would add a version that moves on someone else's
schedule for no benefit, so `--diff` resolves pack membership from the installed
extensions' own `package.json` files and reports children separately rather than
as undeclared.

**Nothing is ever uninstalled.** An extension you added by hand shows up in
`--diff` as undeclared and is left alone. This file is a floor, not a cage —
consistent with `script/update-report`, which lists cleanup candidates instead of
removing them.

## Pinning depends on one VS Code setting

VS Code updates extensions by itself unless `extensions.autoUpdate` is `false`.
With it on, the pins here describe the version that was installed once, not the
version running now, and the file quietly becomes fiction.

The scripts do not edit `settings.json` — that file is yours. Instead
`--verify` warns when the setting is not `false` and reports the drift itself, so
the pins stay honest either way.

## Adding an extension

1. Find the exact id and version. `./script/check-extensions` reports the latest
   published version for everything already declared.
2. Add it with a purpose comment. `tests/vscode-extensions.sh` requires both the
   pinned version and the comment, and rejects a commented-out entry that would
   not parse if enabled.
3. Note the casing. Ids are case-sensitive as published — `golang.Go`,
   `EditorConfig.EditorConfig` — even though `code --install-extension` matches
   case-insensitively. A wrong casing installs fine and then reports as
   permanently missing in `--verify`, which `./script/check-extensions` catches.
4. Run `./script/test`, then `./script/vscode-extensions apply`.
