# Changes from the StikJIT proof of concept

- Merge current LiveContainer fixes into the `stikjit-poc` base while retaining bundled SideStore and existing guest functionality.
- Add a reproducible macOS combined-IPA workflow with pinned SideStore and StikJIT source revisions, logs, Swift tests and archive inspection.
- Add an embedded signing-service bridge using upstream SideStore APIs and its existing database.
- Use the complete installed host for unified self-installation; reject incomplete host bundles before re-signing.
- Journal pending self-refresh before installation; read the installed host profile on subsequent launch and distinguish pending, failed, record-only and verified-host results.
- Serialize unified operations across requests and helpers; report helper launch, interruption and timeout errors.
- Add 48/24-hour policies, foreground checks, best-effort BackgroundTasks opportunities, local reminders and existing Refresh All Apps App Intent routing.
- Add Device/LiveContainer installation selection for source and file pipelines, a configurable default, and source provenance records.
- Retain the source parser/cache and add HTTPS validation, duplicate-source labels, detail sheets and update indicators.
- Add Refresh and JIT navigation, device snapshot rows, and retained access to embedded SideStore authentication and management.
- Copy and validate pairing data atomically instead of moving the original file and reporting unconditional success.
- Default new configurations to integrated StikJIT, improve connection timeout, gate the host's debug entitlement, and retain guest JIT-less behavior.

See README.md and acceptance.md in this directory for unresolved functionality and required device validation. This changelog is not a statement that the seven-day acceptance test passed.
