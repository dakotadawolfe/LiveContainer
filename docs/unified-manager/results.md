# Build and validation record — 2026-10-19 UTC

Status: **development preview built; user device test exposed a bootstrap/database failure**. This is not yet an accepted self-maintaining replacement for Zeus.

## Reported device evidence

The user's screenshots show the c6e5cfa build running on iOS 27.0.1 (24A446), with the host interface and embedded SideStore welcome screen opening. The signing screen reports an inaccessible App Group container; an accompanying Core Data exception reports an attempted save with no persistent stores. The stack has not been symbolicated, so the exact originating save is not established. Inspection found unguarded sign-in and background error-purge paths after failed startup.

Zeus separately offered to remove extensions because four new App IDs were requested and none remained that week. The user subsequently confirmed selecting Remove and Install and then deleting that installation. The installed signing entitlements were not inspected before deletion. The JIT page reports a reachable LocalDevVPN TCP endpoint, but still asks for pairing information. Apple login, JIT launch and self-refresh have not passed. The next attempt will be a fresh bootstrap with all extensions retained.

The bootstrap correction adds host checks for all four extensions and the shared group, waits for database startup before sign-in, and suppresses persistent error logging/purging until startup succeeds. These checks do not reset or delete account or guest data. On-device validation of these corrections remains required.

## Delivered build

- Artifact: `LiveContainer+SideStore.ipa`
- Source commit: `1476cd539ddadf7011024063f1562f305ff45111`
- SHA-256: `77302a1deb593eb6769758e681112368feb1ca472028cf31510b727fcc883e5b`
- [Successful macOS build and logs](https://github.com/dakotadawolfe/LiveContainer/actions/runs/39197571815)
- Toolchain: Xcode 26.6, build 17F113, iPhoneOS 26.5 SDK. The user's iOS 27.0.1 screenshots concern the earlier c6e5cfa build. The corrected build has not yet been tested on the phone.
- Signing state: ad-hoc entitlement requests for a bootstrap installer to replace with valid device provisioning. No personal Apple ID, developer certificate, pairing record, or private key was used by CI.

Later documentation commits do not change this binary. Its embedded `LCUnifiedBuildCommit` matches the source commit above. `main` contains the implementation and these delivery documents; temporary implementation branches have been merged and removed.

## Passed build-time checks

| Check | Observed result |
|---|---|
| Pinned StikJIT 1.9.0 compilation and framework generation | Passed |
| LiveContainer host and extension archive | Passed |
| Pinned SideStore with the manager bridge and refresh guards | Passed |
| Combined IPA packaging | Passed |
| Swift refresh-policy, renewal-identity and bootstrap-prerequisite tests | 6 passed, 0 failures |
| Python malformed-archive and entitlement-parser tests | 6 passed, 0 failures |
| IPA structure inspection | Passed: 362 entries, one host, bundled SideStore, SideStoreSupport, StikJIT helper/runtime, LiveProcess, widget and intent metadata |
| Entitlement request inspection | Passed for host and four extensions; debugger requests present for host and LiveProcess; SideStore App Group requested by every bundle |
| Downloaded artifact inspection on Windows | Passed; checksum matches CI, ZIP CRCs pass, all four extensions present, new bootstrap diagnostic strings and shared-group check found in compiled binaries |
| Pinned SideStore overlay application | Passed local static checks: idempotent application; startup guards precede context creation and authentication cleanup |

The tests reject unchanged/older profile expiry, changed app/team identity, missing combined components, a complete bundle without shared-group access, unsafe archive paths, truncated Mach-O signatures and missing entitlement data. They test decision rules and packaging, not Apple services or runtime behavior. No test reproduces the physical Core Data exception. The build still reports compiler warnings; it is not a warning-free build.

## Not passed or not implemented

No successful Apple ID login, certificate issuance, standalone installation, guest execution, JIT activation, self-installation, self-refresh, data-preservation check, automation run, or seven-day trial has been verified. CI cannot establish those results.

Installed-device provisioning readback for every standalone app remains unimplemented; their displayed expirations come from SideStore's database. Interactive Apple authentication and detailed device management remain in the bundled SideStore screen. Some signing prompts may need that foreground UI instead of a headless helper. Guest credential isolation retains LiveContainer's documented security limitations. These are material limitations, not completed acceptance items.

Follow [setup and migration](setup.md), then fill out the [physical-device acceptance record](acceptance.md). Do not remove the working recovery route until a real full-bundle self-installation and renewal pass. Free personal Apple ID signing with **external LocalDevVPN** is the explicitly selected configuration.

## Logs

The workflow's `build-logs` artifact contains `stikjit.log`, `archive.log`, `sidestore.log`, `package.log`, `rules-tests.log`, `packaging-tests.log`, `toolchain.log`, `ipa-inspection.json` and `entitlement-inspection.json`. The delivery log archive also includes the local downloaded-binary inspection and static overlay check. The first correction build (39197090616) exposed a duplicate Objective-C interface across bridging headers; commit 1476cd5 moved the check behind the existing bridge, and the complete rebuild above passed. The failed-run logs are retained with the delivery. Earlier baseline/integration logs remain local development evidence; the older IPA is superseded.
