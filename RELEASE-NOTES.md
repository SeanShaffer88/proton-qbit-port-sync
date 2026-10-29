Automatically keep qBittorrent's incoming port matched to Proton VPN port forwarding on Windows.

### Easy installation

1. Download **proton-qbit-port-sync-0.1.0-windows.zip** below.
2. Extract the ZIP completely.
3. Enable Proton port forwarding, bind qBittorrent to the Proton VPN network interface, and exit qBittorrent.
4. Double-click **Install.cmd** and follow the prompts. Then open qBittorrent normally.

Requires a paid Proton VPN plan and qBittorrent 5.x. Uses Windows PowerShell 5.1; no administrator rights or extra packages required. Existing Web UI users are prompted for their current login and must bind that UI to 127.0.0.1.

Includes automatic sign-in startup, encrypted credential storage, localhost-only API access, VPN binding checks, an uninstall script, and SHA-256 checksums. No credentials or personal logs are included in the release.

This first release is unsigned. The installer asks before running the included scripts, unblocks only its five packaged PowerShell files, and uses RemoteSigned for that process. It does not change your saved execution policy or override Group Policy. Managed environments may require administrator-approved scripts.

Validated with automated tests on Windows PowerShell 5.1 and PowerShell 7, plus a live qBittorrent/Proton VPN API test. Proton log format changes may require a future update.
