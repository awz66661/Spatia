## Summary

Briefly describe the change and why it belongs in Spatia.

## Type of change

- [ ] App behavior
- [ ] Core scanner/model/layout behavior
- [ ] Documentation
- [ ] Build, packaging, or release tooling
- [ ] Tests only

## Verification

- [ ] `./Scripts/check-env.sh`
- [ ] `./Scripts/build-debug.sh`
- [ ] `./Scripts/test.sh`
- [ ] Manual app check, if UI or packaging behavior changed

## Safety and privacy

- [ ] This change does not add telemetry, networking, background scanning, or automatic cleanup.
- [ ] Filesystem access remains explicit and user initiated.
- [ ] Any deletion-related behavior is reversible and routed through safety policy.
- [ ] Permission or privacy behavior changes are documented.

## Documentation and release impact

- [ ] README or `Docs/` updated, if user-facing behavior changed.
- [ ] Release notes or packaging docs updated, if distribution behavior changed.
- [ ] No notarization, signing, or App Store claims were added without implementation support.
