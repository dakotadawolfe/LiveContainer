# Unified manager development build

This fork keeps LiveContainer as the host, embeds the LiveContainer-compatible SideStore build as a framework, and runs signing and JIT work through LiveProcess. The download is **LiveContainer+SideStore.ipa**. It is an ad-hoc package for a bootstrap installer to sign for your device, not an Apple ID-signed distribution artifact.

The project is not accepted as self-maintaining until the physical-device checklist and seven-day trial pass. Compiling, packaging, returning from a signing API, or reading SideStore's database does not prove that iOS installed a renewed profile.

## Build

Use the `Unified bundled build` GitHub Actions workflow on `main`, or a Mac with Xcode 26.6 and the dependencies shown in that workflow. Windows cannot run Xcode. The workflow:

1. Checks out this repository and its pinned submodules.
2. Builds StikJIT at `32287268fa5824f9edce4cb359f5833ce0cf7b00` (1.9.0 sources, including the personalized DDI mounting repair).
3. Runs Swift refresh-policy tests and Python archive tests.
4. Archives the LiveContainer host and all existing extensions.
5. Builds LiveContainer/SideStore at `ee3cc16a67f9fed766f79a0ed70938f0f8ad5a07`, applying the checked-in service overlay with `scripts/prepare_sidestore.py`.
6. Packages the combined app with `.github/build_github.sh`, preserves entitlement requests using ad-hoc signatures, and inspects the resulting IPA and its host/extension entitlement requests. The package records its source commit in `LCUnifiedBuildCommit`.

The overlay aborts if its exact upstream anchors change. Review new upstream APIs before updating the pin. No Apple ID, certificate, private key, pairing file, or device identifier belongs in CI. See the workflow artifacts for complete archive, SideStore, StikJIT, test, and packaging logs.

The packaging script requires `SIDESTORE_IPA` pointing to the overlaid SideStore build. An ordinary upstream SideStore IPA lacks the manager service and is not a valid substitute. The upstream `dylibify` 1.0 packaging asset observed for this build has SHA-256 `6d23f6a2fc4d8442f87caa1161aebe6ecaafd0e8c41ce205da007efb04fc82c7`. CI pins the source revisions and Xcode selection; Homebrew dependencies and runner images may change, so byte-for-byte reproducibility across future runner images is not claimed.

## Architecture and signing boundaries

Discover reuses LiveContainer's source parser, cache, download helper, and guest installation engine. The install chooser routes device requests to embedded SideStore. `LCUnifiedManagerBridge` uses SideStore's existing `DatabaseManager`, `AppManager`, provisioning, authentication, and installation pipelines. It exports a small metadata snapshot; it does not export account credentials or private keys. Signing remains authoritative in SideStore's database. `UnifiedInstallRecords.json` stores source provenance only, not a second signing database.

Normal self-refresh in the unified service explicitly installs `Bundle.Info.activeBundleURL`, after checking for the bundled SideStore, SideStoreSupport, StikJIT helper, LiveProcess, widget and App Intent metadata. The signing pipeline also rejects an incomplete host before re-signing, preventing a standalone LiveContainer source artifact from replacing this combined build. Updating to a new manager version is a separate, explicit installation of a complete combined IPA.

The coordinator writes the old installed host profile identity and expiry before invoking SideStore. It uses a process lock for host requests and a second lock within the embedded signing engine. On another launch it checks the installed host profile for the same signing identity, a new profile UUID, and a later nonexpired expiration, plus required bundled components. This is a host readback check, not proof that every guest or widget works. Device-app expiry is labeled as a SideStore signing record until device-level verification is performed.

LiveContainer guest isolation is implemented with runtime hooks and allocated keychain groups, not a separate security sandbox for each guest. Upstream also shares signing material with LiveContainer for guest signing. **This architecture cannot guarantee that a malicious native guest cannot reach host credentials, pairing secrets, or host files.** The new bridge does not expose them, but does not establish a security boundary that upstream lacks. Only run guests you trust. Do not claim strong credential isolation from hostile guests.

## Interface

- **Discover:** HTTPS sources, cached catalogs, search, duplicate-source labels, app details, release notes, screenshots, and the installation chooser.
- **Installed:** LiveContainer's guest management and a metadata list of SideStore-managed device apps. Detailed device management and interactive Apple authentication still use the bundled SideStore screen within this same app.
- **Refresh:** Installed host profile, SideStore device records, policy, manual requests, reminders, and persistent history.
- **JIT:** Built-in method, validated pairing import and a local endpoint reachability diagnostic. This diagnostic does not claim successful debugger attachment or guest execution.
- **Settings:** Apple ID/signing entry, default install method, existing certificates and app options, source management and tweaks.

Free-account standalone slots and App ID restrictions are enforced by SideStore. Guests do not consume an additional standalone slot; the host still does. Choosing another destination never silently transfers or deletes data. Export guest data and follow the standalone app's import procedure if moving between destinations; many apps cannot migrate their data.

## Current limitations requiring validation or more work

- This build has not been tested on a physical iPhone. Apple authentication, 2FA, certificate creation/import, standalone installation, self-installation, widget execution, and all JIT execution remain unverified.
- UI prompts required by SideStore may not be presentable from a headless LiveProcess. Use **Apple ID / Signing** to complete setup or permission review. End-to-end interactive installation from the unified service must be tested; a compile does not establish this works.
- The device list is a SideStore snapshot. Live installed-device provisioning readback for every device app is not implemented; do not call those entries verified renewals.
- Foreground opportunities and Shortcuts use the same coordinator. BackgroundTasks requests are best effort. A background timeout can interrupt signing; reopen, verify the installed state, and retry. Never use a missing callback as success.
- The imported pairing format validator recognizes classic Lockdown pairing data. A RemotePairing-only file is not automatically converted to a StikJIT pairing file. Use SideStore's supported pairing setup for its transport.
- StikJIT is rebuilt from current pinned sources, but iPhone 18 Pro / iOS 27.0.1 execution is unverified. TXM/SPTM devices need guest allocator/script cooperation. A connected debugger does not fix an incompatible guest allocator.
- Catalog version comparison is numeric display comparison. Source parser support and compatibility metadata retain upstream limitations; version labels alone do not establish device compatibility.
- Device-specific launching, update/reinstall/uninstall details and signing slot/entitlement review remain in embedded SideStore. A fully unified native management interface is not finished.
- Protected App Groups and keychain access can change when signing identities change. No migration guarantee is made across teams or bundle identifiers.
- The primary build intentionally does not include a VPN extension for a free Apple account. See [VPN feasibility](vpn.md).

## Upstream basis

The host starts from LiveContainer's `stikjit-poc` (`999f44f`) with `main` (`9108ae6`) merged. The bundled integration branch is `LiveContainer/SideStore:LiveContainerSupport`, not stock SideStore. Stock SideStore was inspected at `d97ec133719d79916675bdaf722b82a8d091d545` for comparison. No unrelated third-party auto-refresh patches are included.

References: [LiveContainer](https://github.com/LiveContainer/LiveContainer), [StikJIT branch](https://github.com/LiveContainer/LiveContainer/tree/stikjit-poc), [embedded SideStore](https://github.com/LiveContainer/SideStore), [SideStore](https://github.com/SideStore/SideStore), [StikJIT integration](https://github.com/StikDebug/StikJIT/blob/main/INTEGRATION.md), [upstream issue 1629](https://github.com/LiveContainer/LiveContainer/issues/1629), [LiveContainer documentation](https://livecontainer.github.io/docs/).
