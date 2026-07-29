# Chezmoi instructions

Chezmoi is the configuration engine and owns application of user-level state.

## Rules

- Preserve the preview boundary: changes should be inspectable with
  `chezmoi diff` before application.
- Use `run_onchange_` for operations tied to content changes and `run_once_`
  only for genuinely one-time actions or reminders.
- Keep numeric script ordering meaningful and documented.
- Do not store secrets directly in templates.
- Do not commit machine-specific absolute paths, trust decisions or generated
  credentials.
- Back up user-owned files before destructive replacement.
- Avoid automatic changes to FileVault, Touch ID PAM, Rosetta, network services
  or major macOS updates.

## Validation

```bash
./script/test
chezmoi diff
```

The second command requires a configured macOS environment and may not be
available in Linux CI.
