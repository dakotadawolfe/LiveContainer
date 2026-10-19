# Build and validation record — 2026-10-19 UTC

Status: **development preview built; user device test exposed a bootstrap/database failure**. This is not yet an accepted self-maintaining replacement for Zeus.

## Reported device evidence

The user's screenshots show the c6e5cfa build running on iOS 27.0.1 (24A446), with the host interface and embedded SideStore welcome screen opening. The signing screen reports an inaccessible App Group container; an accompanying Core Data exception reports an attempted save with no persistent stores. The stack has not been symbolicated, so the exact originating save is not established. Inspection found unguarded sign-in and background error-purge paths after failed startup.

Zeus separately offered to remove extensions because four new App IDs were requested and none remained that week. The screenshots do not establish whether the removal option was accepted or which entitlements the installed copy has. The JIT page reports a reachable LocalDevVPN TCP endpoint, but still asks for pairing information. Apple login, JIT launch and self-refresh have not passed.

The bootstrap correction adds host checks for all four extensions and the shared group, waits for database startup before sign-in, and suppresses persistent error logging/purging until startup succeeds. It preserves existing data and provides installation guidance. On-device validation of these corrections remains required.

## Delivered build

- Artifact: `LiveContainer+SideStore.ipa`
- Source commit: `c6e5cfafe9d007dd619d2c779d9fac132024a80b`
- SHA-256: `6db78e394fc10ebb09e4553ade61d64db93580e58ea10b5e1b58850649f197ea`
- [Successful macOS build and logs](https://github.com/dakotadawolfe/LiveContainer/actions/runs/39195285885)
- Toolchain: Xcode 26.6, build 17F113, iPhoneOS 26.5 SDK. The user's iOS 27.0.1 screenshots confirm UI launch only, with the bootstrap failure described above.
- Signing state: ad-hoc entitlement requests for a bootstrap installer to replace with valid device provisioning. No personal Apple ID, developer certificate, pairing record, or private key was used by CI.

Later documentation commits do not change this binary. Its embedded `LCUnifiedBuildCommit` matches the source commit above. `main` contains the implementation and these delivery documents; temporary implementation branches have been merged and removed.

## Passed build-time checks

| Check | Observed result |
|---|---|
| Pinned StikJIT 1.9.0 compilation and framework generation | Passed |
| LiveContainer host and extension archive | Passed |
| Pinned SideStore with the manager bridge and refresh guards | Passed |
| Combined IPA packaging | Passed |
| Swift refresh-policy and renewal-identity tests | 3 passed, 0 failures |
| Python malformed-archive and entitlement-parser tests | 6 passed, 0 failures |
| IPA structure inspection | Passed: 362 entries, one host, bundled SideStore, SideStoreSupport, StikJIT helper/runtime, LiveProcess, widget and intent metadata |
| Entitlement request inspection | Passed for host and four extensions; debugger requests present for host and LiveProcess; SideStore App Group requested by every bundle |
| Downloaded artifact inspection on Windows | Passed; checksum matches CI, StikJIT framework reports 1.9.0, embedded SideStore contains the manager bridge class |

The tests reject unchanged/older profile expiry, changed app/team identity, missing combined components, unsafe archive paths, truncated Mach-O signatures and missing entitlement data. They test decision rules and packaging, not Apple services or runtime behavior. The build still reports compiler warnings; it is not a warning-free build.

## Not passed or not implemented

No successful Apple ID login, certificate issuance, standalone installation, guest execution, JIT activation, self-installation, self-refresh, data-preservation check, automation run, or seven-day trial has been verified. CI cannot establish those results.

Installed-device provisioning readback for every standalone app remains unimplemented; their displayed expirations come from SideStore's database. Interactive Apple authentication and detailed device management remain in the bundled SideStore screen. Some signing prompts may need that foreground UI instead of a headless helper. Guest credential isolation retains LiveContainer's documented security limitations. These are material limitations, not completed acceptance items.

Follow [setup and migration](setup.md), then fill out the [physical-device acceptance record](acceptance.md). Do not remove the working recovery route until a real full-bundle self-installation and renewal pass. Free personal Apple ID signing with **external LocalDevVPN** is the explicitly selected configuration.

## Logs

The workflow's `build-logs` artifact contains `stikjit.log`, `archive.log`, `sidestore.log`, `package.log`, `rules-tests.log`, `packaging-tests.log`, `toolchain.log`, `ipa-inspection.json` and `entitlement-inspection.json`. The delivery log archive also includes the local downloaded-binary inspection. Earlier baseline/integration logs are retained locally as development evidence; the older IPA is superseded.
