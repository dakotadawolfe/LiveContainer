# Source and license notices

This is a development fork, not an official LiveContainer, SideStore, or StikDebug release. Existing upstream copyright notices are retained.

- **LiveContainer:** AGPL-3.0, see the repository's `LICENSE`. The complete modified host source is on this fork's `main` branch; each IPA records its build commit.
- **Embedded SideStore:** AGPL-3.0, [source at the build pin](https://github.com/LiveContainer/SideStore/tree/ee3cc16a67f9fed766f79a0ed70938f0f8ad5a07) and [license](https://github.com/LiveContainer/SideStore/blob/ee3cc16a67f9fed766f79a0ed70938f0f8ad5a07/LICENSE). All changes used by this fork are in `integration/SideStore/UnifiedManagerBridge.swift` and `scripts/prepare_sidestore.py`; the workflow applies them to that exact source revision.
- **StikJIT:** MPL-2.0, [source at the build pin](https://github.com/StikDebug/StikJIT/tree/32287268fa5824f9edce4cb359f5833ce0cf7b00) and [license copy](StikJIT-LICENSE.txt). This build changes compiler/packaging settings without modifying StikJIT's source files. Its upstream dependencies and notices remain applicable.
- **LocalDevVPN:** external App Store application, not copied into or distributed with this IPA.

The build also uses the repositories' pinned submodules and upstream dependencies (including SideSign, minimuxer, OpenSSL and signing/packaging utilities). Their own notices and licenses remain in their source distributions. Follow `.github/workflows/unified.yml` to obtain the exact source trees used for the build. No Apple credentials or private provisioning material are distributed.
