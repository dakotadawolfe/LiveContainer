# Build and validation record — 2026-10-19 UTC

Status: **download-queue preview built and inspected; 22 automated tests passed**. On the previous build the user reports working Apple ID login, device and container installation, guest launch, and combined-IPA self-installation/refresh. Installed-profile renewal comparisons, specifically identified JIT-required guest execution, the new queue's device behavior, and the seven-day trial remain unverified. This is not yet an accepted self-maintaining replacement for Zeus.

## Download queue build

- Artifact: `LiveContainer+SideStore.ipa`, 37,787,685 bytes.
- Source commit: `e008fddabddcc7f04e83ba360d6ae3547684a4e6` on `main`.
- SHA-256: `86065f5c55f5fa564b98b4e003e7ef579407121c2a1b53bf02e958796ee6ff34`.
- [Successful macOS build](https://github.com/dakotadawolfe/LiveContainer/actions/runs/39209931407), Xcode 26.6 (17F113).
- Swift tests: 16 passed, including 10 queue/recovery/filesystem tests. Python packaging/entitlement tests: 6 passed. Zero failures.
- StikJIT, host archive, embedded SideStore, combined packaging and entitlement inspection: passed.
- Downloaded IPA: SHA-256 matches CI, all ZIP CRCs pass, expected source commit and queue implementation found in `LiveContainerSwiftUI.framework`, all four extensions retained. SideStore, SideStoreSupport, StikJIT helper/runtime and intent metadata remain present.
- The archive is ad-hoc signed for installation with the existing developer-signing workflow; CI has not signed it with the user's Apple ID or tested the new queue on an iPhone.
- [Queue behavior and physical-device checks](downloads.md). The previous working release remains available for recovery. Two earlier CI attempts for this feature were intentionally cancelled after newer changes superseded them; the completed run above is the delivered artifact.

## Reported device evidence

The user's screenshots show the c6e5cfa build running on iOS 27.0.1 (24A446), with the host interface and embedded SideStore welcome screen opening. The signing screen reports an inaccessible App Group container; an accompanying Core Data exception reports an attempted save with no persistent stores. The stack has not been symbolicated, so the exact originating save is not established. Inspection found unguarded sign-in and background error-purge paths after failed startup.

Zeus separately offered to remove extensions because four new App IDs were requested and none remained that week. The user subsequently confirmed selecting Remove and Install and then deleting that installation. The installed signing entitlements were not inspected before deletion. The JIT page reports a reachable LocalDevVPN TCP endpoint, but still asks for pairing information. Apple login, JIT launch and self-refresh have not passed. The next attempt will be a fresh bootstrap with all extensions retained.

The bootstrap correction adds host checks for all four extensions and the shared group, waits for database startup before sign-in, and suppresses persistent error logging/purging until startup succeeds. These checks do not reset or delete account or guest data. On-device validation of these corrections remains required.

A subsequent user screenshot of build 1476cd5 on iOS 27.0.1 reaches the SideStore Apple ID form and reports "This action cannot be completed at this time. (-80045)". The earlier database error is not shown in this attempt; this is not a successful login or a full database regression test. The pinned integration branch is still upstream's latest LiveContainerSupport commit, and its SideSign dependency already includes merged 2FA fix PR 5. Other upstream users report the same authentication error. A reversible client-header configuration test is documented in setup.md; its outcome on this phone is pending. No account identifier or screenshot containing it is published here.

The user subsequently confirmed successful login on build 1476cd5, supported by the embedded Settings account screen. Device registration initially failed with `Lockdown session failed` and either `BrokenPipe` (32) or `UnexpectedEof`. Account authentication is a reported device success; certificate provisioning, device registration and installation are not. Existing login configuration should be retained.

Later screenshots confirm both active and preferred protocols are `rppairing` after importing a record from the wireless pairing flow. Bonjour advertises port 49152, matching the configured port. Both automatic VPN discovery and a manual endpoint at `10.7.0.1:49152` fail with connection reset (54). Health Check shows the record loaded with connection down. Its unknown reachability indicator is not an independent failed ping: the implementation clears that result when readiness returns `invalidVPN`.

Two user-supplied console logs were inspected privately, including a fresh process launch at 2026-10-19 00:08 device time with Minimuxer logging enabled. TCP probes succeed, the remote record parses, and `tunnel_create_rppairing_with_options` fails with connection reset or early EOF before the device ID can be read. No successful tunnel is recorded. The fresh launch has overlapping startup calls, but later separate attempts also fail; this does not establish concurrency as the cause. The release gateway enables only native error-level logging, so these logs do not identify the individual failed handshake step or prove an invalid pairing key. A USB-created remote record, independently validated with idevice_pair, is the next proposed comparison and has not been tested. No raw logs, account identifiers or pairing material are committed.

## Previous bootstrap build

After repeating pairing, the user supplied a 00:12 device screenshot on build 1476cd5 showing SideStore Ready, Wi-Fi active, device reachable, pairing file verified, and DDI mounted, using Remote Server mode with endpoint 10.7.0.1. This establishes a successful live pairing check after the earlier failures. The user reported repeating the pairing flow; no USB comparison was reported. It does not establish the exact cause of the previous resets, Apple device registration, an installation, debugger attachment, or guest JIT execution. The next gates are confirmation of Apple device registration and full combined-IPA self-installation, followed by installed-profile renewal verification.

- Artifact: `LiveContainer+SideStore.ipa`
- Source commit: `1476cd539ddadf7011024063f1562f305ff45111`
- SHA-256: `77302a1deb593eb6769758e681112368feb1ca472028cf31510b727fcc883e5b`
- [Successful macOS build and logs](https://github.com/dakotadawolfe/LiveContainer/actions/runs/39197571815)
- Toolchain: Xcode 26.6, build 17F113, iPhoneOS 26.5 SDK. User screenshots cover both the earlier c6e5cfa database failure and the corrected 1476cd5 build's subsequent authentication error. Neither attempt establishes successful signing or refresh.
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

After the pairing check, the user reported successfully reinstalling/refreshing the same combined IPA through embedded SideStore following the Impactor bootstrap, successfully installing a standalone app with Install to Device, and successfully installing and launching container apps after resolving the JIT-less certificate setup message. These are user-reported device results on the previous build. Installed profile UUID/expiration comparisons, complete data-preservation checks, a specifically identified JIT-required guest, automation and the seven-day trial have not been independently recorded. The new download queue still requires its own [device acceptance checks](downloads.md).

Installed-device provisioning readback for every standalone app remains unimplemented; their displayed expirations come from SideStore's database. Interactive Apple authentication and detailed device management remain in the bundled SideStore screen. Some signing prompts may need that foreground UI instead of a headless helper. Guest credential isolation retains LiveContainer's documented security limitations. These are material limitations, not completed acceptance items.

Follow [setup and migration](setup.md), then fill out the [physical-device acceptance record](acceptance.md). Do not remove the working recovery route until a real full-bundle self-installation and renewal pass. Free personal Apple ID signing with **external LocalDevVPN** is the explicitly selected configuration.

## Logs

The workflow's `build-logs` artifact contains `stikjit.log`, `archive.log`, `sidestore.log`, `package.log`, `rules-tests.log`, `packaging-tests.log`, `toolchain.log`, `ipa-inspection.json` and `entitlement-inspection.json`. The delivery log archive also includes the local downloaded-binary inspection and static overlay check. The first correction build (39197090616) exposed a duplicate Objective-C interface across bridging headers; commit 1476cd5 moved the check behind the existing bridge, and the complete rebuild above passed. The failed-run logs are retained with the delivery. Earlier baseline/integration logs remain local development evidence; the older IPA is superseded.
