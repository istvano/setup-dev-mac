## Summary

<!-- What changes, and why. -->

## Validation

```
./script/test
```

- [ ] `./script/test` passes
- [ ] On macOS: `chezmoi diff` reviewed and `./script/verify` passes
- [ ] Documentation updated in this patch (behaviour, defaults, commands,
      placement or security assumptions)

## Package changes

Delete this section if no package was added, removed or moved.

- [ ] Concrete use case stated
- [ ] Placement decided and justified: host, project uv environment, container
      or isolated VM
- [ ] Profile assignment, with a purpose comment on the entry
- [ ] Conflict analysis against existing tools
- [ ] Licence classified: free, paid or conditional commercial use
- [ ] `./script/check-tokens` passes
- [ ] Any Accessibility, Screen Recording, Input Monitoring, Full Disk Access or
      driver-extension requirement documented in the purpose comment

## Security review

- [ ] No credentials, recovery keys, private hostnames or machine-specific
      absolute paths in tracked files
- [ ] No new remote-script execution beyond the documented bootstrap boundary
- [ ] No security invariant from `AGENTS.md` weakened without an ADR
