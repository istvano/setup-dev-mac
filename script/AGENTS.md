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
- Return non-zero on validation failure.
- Add or update tests for behaviour changes.

## Validation

```bash
bash -n script/<changed-script>
shellcheck -x script/<changed-script>
./script/test
```
