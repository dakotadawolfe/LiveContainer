# Changes from the StikJIT proof of concept

- Queue up to three concurrent IPA downloads without a blocking progress screen or tab switch. Keep per-app progress, cancel/retry actions, source provenance and a persistent journal.
- Use background URLSession transfers, reattach downloads after launch, and serialize installations. Interrupted installations require review rather than reporting success.
- Support multiple IPA selections from Files. Stage and sign container updates before replacing the existing bundle; retain guest data and settings. Replacement choices wait inside Downloads.
- Block Apple ID sign-in until SideStore's database has started, and avoid database maintenance/error saves after failed startup.
- Check App Group access and all four bundled extensions before opening the signing screen or starting refresh; explain how to recover an incomplete bootstrap without resetting data.
- Merge current LiveContainer fixes into the `stikjit-poc` base while retaining bundled SideStore and existing guest functionality.
- Add a reproducible macOS combined-IPA workflow with pinned SideStore and StikJIT source revisions, logs, Swift tests and archive inspection.
- Add an embedded signing-service bridge using upstream SideStore APIs and its existing database.
- Use the complete installed host for unified self-installation; reject incomplete host bundles before re-signing.
- Journal pending self-refresh before installation; read the installed host profile on subsequent launch and distinguish pending, failed, record-only and verified-host results.
- Serialize unified operations across requests and helpers; report helper launch, interruption and timeout errors.
- Give each helper request a separate callback receiver and tear down its connection after completion, preventing a late reply from completing a later operation.
- Register the background task using the identifier in the signed bundle and replace stale expiration reminders when records change.
- Add 48/24-hour policies, foreground checks, best-effort BackgroundTasks opportunities, local reminders and existing Refresh All Apps App Intent routing.
- Add Device/LiveContainer installation selection for source and file pipelines, a configurable default, and source provenance records.
- Retain the source parser/cache and add HTTPS validation, duplicate-source labels, detail sheets and update indicators.
- Add Refresh and JIT navigation, device snapshot rows, and retained access to embedded SideStore authentication and management.
- Copy and validate pairing data atomically instead of moving the original file and reporting unconditional success.
- Default new configurations to integrated StikJIT, improve connection timeout, gate the host's debug entitlement, and retain guest JIT-less behavior.
- Validate packaged Mach-O entitlement requests and include the build commit in the combined IPA.
- Keep external LocalDevVPN for the explicitly selected free-account configuration.

See README.md and acceptance.md in this directory for unresolved functionality and required device validation. This changelog is not a statement that the seven-day acceptance test passed.
