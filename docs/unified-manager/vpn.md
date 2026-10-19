# LocalDevVPN embedding feasibility

The requested free Apple ID build cannot include a functioning LocalDevVPN tunnel extension under Apple's supported provisioning rules.

LocalDevVPN's source declares `com.apple.developer.networking.networkextension = packet-tunnel-provider` on its TunnelProv extension and host, plus `com.apple.developer.networking.vpn.api = allow-vpn` on the host. Apple's capability table lists Network Extensions and Personal VPN for the paid Apple Developer Program / Enterprise Program columns, with no support in the free Apple Developer column. This was checked against the actual table markup on 2026-10-19 UTC.

Copying an extension into the IPA does not grant its entitlement. Removing the entitlement prevents the tunnel from functioning. Re-signing an App Store VPN binary with a free account does not retain Apple's original provisioning authorization.

Therefore the free-account build uses the existing external App Store LocalDevVPN utility. It does not consume a free sideloaded-app slot. A Shortcuts automation may connect its configured VPN before refresh, when the OS offers that action.

Project decision: keep free personal Apple ID signing and external LocalDevVPN, as explicitly selected by the user. An embedded paid-account VPN target is outside this build's scope.

With paid membership, a future build could add a packet-tunnel target under this manager's bundle ID and integrate LocalDevVPN's tunnel implementation and configuration UI, preserving its license. That still needs correct profiles for host and extension, user consent to add VPN configuration, tests of local routing and background operation, and verification that SideStore preserves those entitlements during self-refresh. No such paid-account build or test has been performed here.

Sources: [LocalDevVPN](https://github.com/jkcoxson/LocalDevVPN), [host entitlements](https://github.com/jkcoxson/LocalDevVPN/blob/main/LocalDevVPN/LocalDevVPN.entitlements), [Apple capability table](https://developer.apple.com/help/account/reference/supported-capabilities-ios/), [configuring Network Extensions](https://developer.apple.com/documentation/xcode/configuring-network-extensions/).
