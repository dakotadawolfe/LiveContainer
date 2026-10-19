# Download and installation queue

Choose Install in LiveContainer in Discover or import an IPA from Installed. The request enters a persistent queue without switching tabs or covering the screen. Up to three IPAs download concurrently; installations run one at a time through the existing manager operation lock. Device installations still use embedded SideStore.

Tap the compact Downloads bar to inspect individual progress, cancel a queued/download operation, or retry a failure. Duplicate active requests for the same download URL and destination open the existing queue. Completed and cancelled entries can be cleared. A replacement choice appears inside the queue, with a notice in the bar; it never silently replaces another container. Once installation starts, cancellation is unavailable to avoid partially removing an application.

The manager stages and patches/signs a guest before atomically exchanging it with its existing bundle. The replacement keeps the existing data-container identifiers and settings. A failed preparation or exchange leaves the installed version intact. The queue stores source provenance separately for every job.

## iOS execution limits

Downloads use a stable background URLSession and are reattached after relaunch. Downloaded IPAs and the queue journal live in Documents/TransferQueue. Files are moved out of URLSession's temporary location before its delegate returns. iOS controls when background transfers run; force-quitting can cancel them. See [Apple's background download documentation](https://developer.apple.com/documentation/foundation/downloading-files-in-the-background).

Installations start while the manager is active and request limited extra execution time if it backgrounds mid-operation. There is no promise that iOS will allow installation to finish while suspended. Reopen the manager to install waiting IPAs. An interrupted installation becomes Needs attention rather than an assumed success or an automatic repeat; inspect Installed, then Retry if needed. A finished download can be retried for installation without downloading it again.

## Automated checks

`swift test` covers journal round trips, independent job identities, interrupted-install recovery, background-transfer reattachment, staged-download recovery, missing IPA detection, terminal states, and unknown/misreported download lengths. Filesystem tests exercise actual bundle exchange, failed replacement, and a new installation on macOS. Existing refresh and packaging tests remain required. CI archives the complete host and packages embedded SideStore, StikJIT and all helper extensions.

## Physical-device checks (not yet verified for this change)

- Start four different container downloads. Three transfer concurrently; the fourth starts when a slot opens. Keep browsing sources and switching tabs throughout.
- Confirm newly downloaded guests install one at a time and appear in Installed without reopening the app.
- Cancel one download while others continue; retry a failed URL and verify it does not affect other jobs.
- Leave the app normally during a large download, then return. Check progress and pending installation. Test system termination and user force-quit separately.
- Replace a guest that has saved data. Verify the choice waits in Downloads, then verify the updated guest retains that data and app settings.
- Try a malformed/encrypted IPA as an update. Verify the original guest remains usable.
- Interrupt an installation, reopen, and verify it says completion was not verified. Check Installed before retrying.
- Verify Device installation, self-refresh, certificate import, and guest launch/JIT continue to work with the full combined IPA.
