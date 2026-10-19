# Physical-device acceptance record

Status: **not executed**. No item below is passed by CI. Record artifact SHA-256, commit, device model, exact iOS build, signing team (keep identifiers private), test time, observations, and failure evidence. Never put credentials, private keys, anisette payloads, UDIDs or pairing contents in public logs.

## Bootstrap and signing

- [ ] Bootstrap the complete IPA, preserving all extensions and framework bundles.
- [ ] Embedded SideStore opens with only one manager Home Screen icon; no separate SideStore/StikDebug installed.
- [ ] Apple ID login and 2FA work; certificate generation/import works.
- [ ] Pairing and LocalDevVPN establish the required signing transport.
- [ ] Correctly self-install the complete IPA through embedded SideStore as required by issue 1629.
- [ ] Verify host Team ID, bundle ID, App Groups, keychain groups, extension identities and get-task-allow after signing.
- [ ] Document whether Zeus bootstrap worked; otherwise document the exact successful iloader/Impactor settings.

## Install, source and data flows

- [ ] Add/edit/remove/refresh valid sources; retain useful errors/cache for invalid/unreachable sources.
- [ ] Search catalogs, inspect screenshots/release notes and distinguish the same bundle ID from two sources.
- [ ] Install chooser is shown for source and file imports; defaults are honored.
- [ ] Device install invokes signing/permission review and produces a separate Home Screen app.
- [ ] Slot/App ID exhaustion is reported; choosing a guest is an explicit alternative.
- [ ] Guest install runs without an extra standalone slot; JIT-less launch still works.
- [ ] Source updates preserve both guest and standalone test data. Refresh retains the old version.
- [ ] Direct HTTPS URL and Files imports work, including cancellation and an invalid IPA.
- [ ] Existing guest containers, scripts, shortcuts, tweaks and app-specific settings still work.
- [ ] Device management via embedded SideStore supports launch, update, uninstall and reinstall as expected.

## Mandatory self-refresh

- [ ] Save old **installed** provisioning profile UUID/expiry and a version/data baseline.
- [ ] Disconnect the computer and stop using Zeus.
- [ ] Refresh the combined host with a personal Apple ID, including a real installation of its entire bundle.
- [ ] Reopen and independently confirm a new installed profile with later expiry and unchanged app identity/version.
- [ ] Confirm SideStore, LiveContainer, StikJIT, LiveProcess, widget, intents, settings, catalogs and guest data remain intact.
- [ ] Refresh a managed standalone app and independently verify its installed-device profile expiry, not just the database value.
- [ ] Repeat after interrupted/suspended installation; history remains pending/unverified until readback.
- [ ] Concurrent button, foreground and Shortcut attempts do not create conflicting installations.
- [ ] A standalone LiveContainer IPA cannot replace the combined host through a refresh/update path.
- [ ] Errors for expired authentication, 2FA, certificates, no VPN, invalid pairing and no space remain actionable.

## JIT and automation

- [ ] Existing device pairing imports without deleting the source file or corrupting the previous record on failure.
- [ ] Integrated StikJIT launches a compatible guest without StikDebug, including after reboot/DDI remount.
- [ ] A guest with incompatible executable-memory behavior fails honestly instead of being labeled JIT-ready.
- [ ] Shortcuts refresh can execute with the proper VPN state and returns accurate pending/error results.
- [ ] Foreground expiration policy and retries behave at 48-hour and 24-hour deadlines.
- [ ] Background opportunities and expiration notifications are observed on the physical phone.

## Seven-day trial

For each day record: installed host/device expiry before and after; trigger (foreground/Shortcut/background); VPN and network state; locked/unlocked; battery/Low Power Mode; authentication prompts; data check; whether unattended completion was actually observed.

| Day | Trigger and conditions | Host expiry before/after | Device expiry before/after | User action needed | Data/bundles intact | Evidence |
|---|---|---|---|---|---|---|
| 1 | Not run | | | | | |
| 2 | Not run | | | | | |
| 3 | Not run | | | | | |
| 4 | Not run | | | | | |
| 5 | Not run | | | | | |
| 6 | Not run | | | | | |
| 7 | Not run | | | | | |

Only mark the self-maintaining goal accepted after this record passes. A renewed certificate without verified installation is not acceptance.
