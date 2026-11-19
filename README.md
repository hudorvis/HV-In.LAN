# In.LAN v26.11.19.01

Universal iPhone and iPad app for discovering and monitoring devices on a local IPv4 Wi-Fi or Ethernet network. Build 3 continues In.LAN v26.11.18.01 (Build 2). The bundle ID is `au.h-v.in.lan`, the App Store version is 1.0 and the minimum OS is iOS or iPadOS 17.

Open `InLAN.xcodeproj` and select the shared `InLAN` scheme. The GitHub Actions workflow tests the network probe, device state, saved data and subnet ranges, then builds the Debug simulator app and Release device app. The simulator app is available from the workflow run. For a physical device, select your signing team in Xcode or use the Codemagic signing workflow. The App Store Connect integration in `codemagic.yaml` is named `In.LAN`.

## Using the scanner

Tap Scan Once for a single sweep. Scan Continuously repeats discovery and refreshes saved devices between and during sweeps. Either active control changes to Stop. Backgrounding the app ends scanning. Changing networks ends the active scan and clears current reachability. Open Scan Setup from the network status row in Devices.

Automatic and Quick /24 scan the local /24 or the actual subnet if smaller. Full Subnet supports networks down to /16. Custom Range accepts up to 4,094 consecutive on-link IPv4 addresses. Saved devices on the same subnet and local Bonjour advertisements can appear outside the quick sweep. Cellular, tunnels, routed VLANs and IPv6-only hosts are outside this revision's scope.

Green indicates an echo reply below 30 ms and yellow indicates 30 ms or above. A TCP handshake, connection refusal or resolved Bonjour advertisement can establish reachability with grey No Ping status. Only a successful handshake identifies an accepted TCP port. A failed check of a known host can show Offline. Unchecked indicates that current reachability is unknown.

Latency and loss describe ICMP echo attempts. The detail history and statistics cover up to 60 attempts. Gaps represent missed replies. The detail Ping action probes one address. Devices are identified by IPv4 address. Saved devices, custom names and their historical samples use the existing local storage key. On a DHCP network, a reused address can therefore carry the previous label.

Bonjour browses the eight service types listed in Info.plist using Apple's Network and DNS-SD APIs. Resolved services include the advertised port. Reverse DNS runs separately so an unanswered name lookup does not delay the device row. SSDP remains planned.

## Audit and device acceptance

Build 3 finishes pending Bonjour and reverse-DNS lookups before a single scan reports completion. During continuous scanning, it refreshes service observations and keeps their observation times for Last Seen. Switching LANs clears live state. The store recovers readable saved devices when a sibling record is damaged.

On a physical iPhone or iPad, allow Local Network access, run Scan Once, save and rename a device, and relaunch. Check continuous monitoring against an echo-capable host, an ICMP-blocking host with TCP or a declared Bonjour service, and a saved host disconnected from the network. Also exercise permission denial and retry after enabling access in Settings. Rotate the iPhone both ways and the iPad through all four orientations. Resize an iPad window until Monitor changes from multiple columns to one.
