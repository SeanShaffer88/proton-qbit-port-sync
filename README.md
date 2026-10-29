# Proton qBittorrent Port Sync

A small Windows background watcher that keeps qBittorrent's incoming port matched to Proton VPN's active forwarded port. No Python, third-party packages, administrator account, or qBittorrent restart required.

**Initial release:** supports the Proton VPN Windows client log format and qBittorrent 5.x. This is an independent community project, not affiliated with Proton or qBittorrent.

## How it works

Every 10 seconds, the watcher checks that the configured VPN adapter is up, reads the latest successful port-forwarding lease from Proton's local client log, and updates qBittorrent through its authenticated localhost API. It verifies the result and preserves the configured VPN interface binding. It disables qBittorrent's random listening port and UPnP/NAT-PMP to keep the forwarded port consistent.

The watcher waits when qBittorrent is closed, the VPN is disconnected, or the latest lease is missing, stale, or unsuccessful. It never launches qBittorrent or reconnects Proton. Its log contains status and port numbers, not passwords or copies of Proton logs.

## Requirements

- Windows 10/11 and Windows PowerShell 5.1 with .NET Framework 4.7.2 or newer (PowerShell 7 also works).
- Paid Proton VPN plan, connected to a server supporting P2P, with port forwarding enabled.
- qBittorrent 5.x already bound to the Proton adapter: **Tools > Options > Advanced > Network interface**. Default adapter name: `ProtonVPN`.
- Scripts must be allowed by your existing execution policy. Managed PCs may restrict scripts; this project does not change execution policy.

Follow [Proton's port-forwarding setup](https://protonvpn.com/support/port-forwarding) first.

## Install

### Windows setup executable (recommended)

Download **proton-qbit-port-sync-0.2.0-setup.exe** from [Releases](https://github.com/SeanShaffer88/proton-qbit-port-sync/releases/latest), open it, and follow the wizard on 64-bit Windows 10/11. No manual PowerShell commands, extra packages, or administrator rights required. Prepare Proton port forwarding and the qBittorrent VPN binding first, then exit qBittorrent before installing.

The wizard checks prerequisites, upgrades existing Port Sync installations while preserving settings, and registers an uninstaller in **Windows Settings > Apps > Installed apps** and the Start menu. It runs bundled configuration scripts behind the scenes with a process-scoped `RemoteSigned` policy, without changing your saved execution policy. The executable is unsigned; organization policies may restrict it.

Existing independent qBittorrent Web UI users should use the ZIP installer below to provide their current credentials. The EXE refuses to replace an existing Web UI login. Uninstall removes startup and application files, but retains runtime configuration, encrypted credentials, backups, and qBittorrent preferences.

See the [wizard preview](installer/preview.md). Build from source using `installer/Get-Compiler.ps1`, then use the returned Inno Setup compiler path to compile `installer/Setup.iss`. The compiler download comes from the official upstream release and is checked against a pinned SHA-256 hash. Its own license applies to building; this project's source is MIT licensed.

### Download and double-click

Download the Windows ZIP from [Releases](https://github.com/SeanShaffer88/proton-qbit-port-sync/releases/latest), extract it completely, and double-click **Install.cmd**. After confirming that the package came from this repository, follow the setup prompts. No administrator rights or extra downloads required.

Setup preview:

```text
Proton qBittorrent Port Sync - Setup
-----------------------------------
Before installing:
  1. Enable port forwarding in your paid Proton VPN app.
  2. In qBittorrent > Options > Advanced, select the ProtonVPN network interface.
  3. Exit qBittorrent completely, including its tray icon.

Ready to install? [Y/N]
Installation complete. Open qBittorrent normally.
```

The launcher unblocks only the five packaged PowerShell files and uses a process-scoped `RemoteSigned` policy; it does not change your saved execution policy. Organization policy can still prevent installation. This release is unsigned.

### Command-line installation

1. Download the source ZIP from GitHub and extract it. Review the scripts. If Windows marks downloaded scripts as blocked, use the file's Properties > Unblock for the files you have reviewed.
2. Exit qBittorrent completely, including its tray icon. Open Proton VPN at least once so its log exists.
3. Open a PowerShell session that permits local scripts in the extracted project directory and run (PowerShell 7 is recommended):

```powershell
.\Install.ps1
```

The installer backs up qBittorrent's INI, enables a password-protected API listening only on `127.0.0.1:18765`, and stores a generated credential encrypted with Windows DPAPI for your Windows user. Runtime files are restricted to your account and SYSTEM. It adds a per-user Startup shortcut and starts the watcher hidden. Open qBittorrent normally afterward.

The original source folder can be moved or removed after installation. The installed copy lives in `%LOCALAPPDATA%\ProtonQbitPortSync`.

Custom installation:

```powershell
.\Install.ps1 -AdapterName 'ProtonVPN' -ApiPort 18765 -PollSeconds 10 `
  -QbitConfigPath "$env:APPDATA\qBittorrent\qBittorrent.ini" `
  -ProtonLogPath "$env:LOCALAPPDATA\Proton\Proton VPN\Logs\client-logs.txt"
```

If Web UI is already enabled, the installer refuses to overwrite it. Bind the existing Web UI to `127.0.0.1`, then supply its port and credential:

```powershell
.\Install.ps1 -ApiPort 8080 -ExistingWebUICredential (Get-Credential)
```

The watcher has the same administrative access to qBittorrent as its Web UI credential. Keep the runtime directory private. DPAPI protects the saved password from other accounts, but cannot protect it from programs already running as you.

## Status and troubleshooting

```powershell
Get-Content "$env:LOCALAPPDATA\ProtonQbitPortSync\sync.log" -Tail 20
```

- **Waiting for VPN/client:** connect Proton and open qBittorrent. Check the adapter name in runtime `config.json`.
- **Waiting for a lease:** enable Proton port forwarding and wait for its next refresh. The parser accepts the latest `SleepingUntilRefresh` record only, up to 90 seconds old. Transitional records defer updates until a successful refresh.
- **API error:** check that qBittorrent Web UI is enabled, the port matches runtime configuration, and credentials have not changed. To reinstall, exit qBittorrent, uninstall with `-RestoreWebUI`, and move the retained runtime directory aside. If Web UI existed before installation, supply its current credentials on reinstall.
- **Binding changed:** the watcher refuses updates if qBittorrent's interface ID differs from installation. Recheck your VPN binding, then reinstall if the adapter was recreated.
- **Watcher not starting:** run the installed `Watch-Port.ps1` in a PowerShell window to see startup errors. Check execution policy, Startup apps, and antivirus policy; do not disable protections.

Proton log formats can change. Unsupported or ambiguous records are ignored. Port matching improves incoming connectivity; it cannot guarantee torrent speed or compensate for slow Wi-Fi, overloaded servers, or limited peers. This watcher is not a VPN kill switch.

## Stop and uninstall

```powershell
& "$env:LOCALAPPDATA\ProtonQbitPortSync\Uninstall.ps1"
```

This stops the watcher and removes its Startup shortcut. To also disable the Web UI enabled by this installer, exit qBittorrent and add `-RestoreWebUI`. Existing Web UI installations are left alone. Runtime files, the encrypted credential, and the pre-installation backup are retained so you can inspect or remove them yourself. Other qBittorrent preferences are not rolled back.

## Development

```powershell
.\tests\Test.ps1
```

Tests cover stale/error/malformed leases, preserving INI sections and VPN binding, API updates and verification, refusing changed bindings and nonlocal endpoints, and script syntax. API tests use a test double and require no real credentials or downloads. GitHub Actions runs them on Windows PowerShell 5.1 and PowerShell 7.

Implementation references: [qBittorrent Web API](https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-%28qBittorrent-4.1%29), [qBittorrent password implementation](https://github.com/qbittorrent/qBittorrent/blob/release-5.2.4/src/base/utils/password.cpp).

MIT licensed. Contributions and reports with redacted log examples are welcome. Never attach credentials, complete Proton logs, personal IP addresses, or runtime configuration to a public issue.
