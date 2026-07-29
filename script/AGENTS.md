# Script instructions

Scripts are the canonical implementation layer. The `justfile` should delegate
to them and contain minimal logic.

## Requirements

- Use Bash strict mode.
- Be idempotent where the operation can be repeated.
- Validate user choices before making changes.
- Never assume root execution; request `sudo` only for the narrow command that
  requires it.
- Keep macOS-only operations guarded by platform checks.
- Avoid implicit network access in validation commands.
- Do not overwrite unrelated user files.
- Return non-zero on validation failure. An audit or verification command must
  be able to fail; printing a warning and exiting 0 gates nothing.
- Declare `local` variables one per line when a later value references an
  earlier one: bash expands every argument to `local` before assigning any.
- Add or update tests for behaviour changes.

## Validation

```bash
bash -n script/<changed-script>
shellcheck -x script/<changed-script>
shfmt -d -i 2 -ci script/<changed-script>
./script/test
```

New scripts are discovered automatically by `script/shell-files`, which selects
by shebang. Do not add a filename-extension-based selector anywhere.
