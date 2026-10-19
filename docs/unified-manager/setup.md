# Bootstrap, migration, and daily operation

## Back up before changing signing identity

Export important guest containers through LiveContainer's existing container/data tools. Keep a copy outside the app's sandbox, and verify the export can be opened. Preserve the original working Zeus-installed app and pairing record until the replacement has passed self-refresh. Do not delete the working app as a speculative troubleshooting step.

Record the old bundle ID, signing Team ID, profile expiration, guest list and app data checksums or sample records. Changing the team or bundle ID can require a separate installation and can make old App Groups/keychain data inaccessible. Installation over an existing app is only a possible preservation route when iOS accepts the signing/application identity. Backups cannot guarantee recovery of keychain-only data.

## Initial installation

1. Download this fork's complete `LiveContainer+SideStore.ipa` and compare its SHA-256 with the build inspection report.
2. Zeus is an **unverified** bootstrap route. It must retain LiveProcess, the widget, bundled frameworks, developer entitlements, App Groups and keychain groups. An enterprise/distribution signature without `get-task-allow` cannot provide the required JIT behavior.
3. Prefer upstream's documented iloader or Impactor bootstrap route if Zeus cannot preserve these. With [Impactor, select Only Register Main Bundle](https://livecontainer.github.io/docs/installation/lc_sidestore). This keeps the extension bundles; it is not the same as removing them. Upstream recommends remote pairing (17.4+) with Impactor. Do not assume the first bootstrap signing pass configured the complete bundled app correctly. A new main App ID still requires available registration capacity; this option does not reset Apple's quota.
4. Enable Developer Mode and trust the developer installation when prompted by iOS.
5. Open **Settings → Apple ID / Signing** in the combined app. Complete SideStore's existing Apple Account/2FA flow on the phone. Do not give credentials or pairing files to the build system or an arbitrary source server.
6. Follow embedded SideStore's pairing setup for this device and connect LocalDevVPN. Use Wi-Fi for the first controlled test. The StikJIT pairing picker recognizes Lockdown records; remote pairing and Lockdown pairing are not interchangeable by renaming the file.
7. Following [issue 1629](https://github.com/LiveContainer/LiveContainer/issues/1629), use embedded SideStore's **Install IPA** with the same full combined IPA to establish the correctly signed installation. Do not substitute its **Resign** button for this bootstrap step. Keep all required extensions. Inspect any signing/certificate errors before continuing.
8. Reopen the combined manager and import the SideStore certificate into LiveContainer through the existing certificate settings if required for JIT-less signing.
9. Record the installed host expiration in **Refresh**. Trigger **Refresh Everything Now**, reopen after installation, and check that expiration actually advances under the same identity, bundled SideStore opens, StikJIT remains present, and app data is intact.
10. Only after the real self-installation and device-app refresh checks pass should Zeus be removed from routine use. Retain a recovery copy of the complete IPA outside the app.

If authentication fails, open the embedded signing screen and complete reauthentication/2FA there. Issue 1629 lists specific upstream recovery steps for newer login and database failures; back up before considering destructive resets. This fork does not automatically wipe accounts, pairing, caches or data to hide an error.

### App Group error or "no persistent stores" during sign-in

The reported Zeus installation reached the host UI, but embedded SideStore could not access its App Group container. The later Core Data save exception is consistent with continuing authentication after database startup failed; it is not evidence of a wrong Apple password. The precise signing entitlements of that installed copy have not been inspected.

Do not retry authentication, choose **Remove and Install**, delete the working installation, or use **Nuke SideStore** for this error. Export guest data first. Reinstall this fork's full combined IPA using the supported Impactor settings above, retaining the same account and application identity where possible. Verify preservation rather than assuming an in-place installation will retain every App Group or keychain item. If the installer needs a new main App ID and Apple reports no capacity, wait for the existing registrations to expire. Removing apps does not make the weekly App ID warning equivalent to the three-active-app limit.

After reinstalling, embedded SideStore must open its shared database before Apple login can work. Then perform the full-IPA self-installation in step 7. The startup guards only reject an incomplete installation: they cannot grant missing entitlements, reset registration limits, or prove self-refresh. No private database fallback is created because helpers and widgets must use the same store.

The reported LocalDevVPN endpoint success establishes TCP connectivity only. It does not validate App Groups, pairing, extension retention, Apple authentication, or JIT execution.

## Sources, installation, and updates

In Discover, add an HTTPS source. Tap an app for details. Install offers **Device** or **LiveContainer** unless a default was explicitly selected in Settings. Device installs consume free-account slots and registered App IDs; use LiveContainer for a compatible app if no slot is available. A failed device attempt does not automatically install a guest.

Use Installed's existing Files/direct-URL import controls for other IPAs. Source provenance is retained for successful source installations. An update is an explicit installation of a newer IPA into the same destination. Guest replacement retains the existing container through LiveContainer's existing replacement choice. Device updates use SideStore's existing app identity and data-preservation rules; confirm preservation on the device. Refresh renews the existing version; it must not silently download a newer version.

## Automatic refresh and Shortcuts

The default policy targets 48 hours before expiry and retries on later opportunities, with at least six hours between automatic attempts. A 24-hour policy and Manual Only are available. For free provisioning this normally means the first attempt around day five, not an exact timer.

1. In Refresh, enable notifications and select a policy.
2. Open Apple's Shortcuts app → Automation → create a daily Time of Day automation.
3. Add the system's Set VPN action for the installed LocalDevVPN configuration if offered on this device, followed by the combined app's **Refresh All Apps** action. If Set VPN is unavailable, connect the VPN before running refresh.
4. Choose Run Immediately if available. Run the automation manually once while unlocked and connected to Wi-Fi. Confirm the host/managed app results, not merely a successful shortcut notification.
5. Keep the daily automation as an additional opportunity. Foreground checks and BackgroundTasks provide other opportunities; iOS can defer or deny them. Reauthentication, VPN disconnection, Low Power Mode, force quitting, suspension or task expiration can require intervention.

There is no implemented guarantee that connecting a VPN automatically launches this manager. Shortcuts' available triggers and actions must be checked on the target iOS version. Apple explicitly states that `earliestBeginDate` is not a promised background execution time: [BGTaskRequest documentation](https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate), [background strategy guidance](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app).

If the host expires before recovery, bootstrap the full combined IPA again using the same team and bundle identity when possible. Do not delete the existing data container first. An expired host cannot schedule its own recovery while iOS refuses to launch it.

## JIT

Select built-in StikJIT in JIT/settings. Import a valid pairing record for this phone. Connect LocalDevVPN and test the local endpoint. The test only establishes TCP reachability. Launch a compatible guest configured to require JIT, with the script matching that guest's executable-memory protocol. Keep the helper extension and `get-task-allow` entitlement. Verify actual guest execution after attachment, including after a reboot; do not infer it from the debugger connecting.
