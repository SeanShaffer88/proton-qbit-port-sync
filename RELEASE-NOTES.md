### Native Windows installer

Download **proton-qbit-port-sync-0.2.0-setup.exe** below and follow the setup wizard. No manual script commands or administrator rights required.

Before installing, enable port forwarding in paid Proton VPN, bind qBittorrent to its Proton VPN network interface, and exit qBittorrent completely.

- Native wizard with prerequisite checks and specific recovery instructions.
- Per-user installation and automatic sign-in startup.
- Windows Installed apps and Start menu uninstaller.
- Upgrades existing Port Sync installations while preserving settings and encrypted credentials.
- Authenticated API restricted to this PC; VPN interface binding remains unchanged.
- ZIP installer remains available for custom paths and existing independent Web UI credentials.
- SHA256SUMS.txt covers both the EXE and ZIP.

The executable is unsigned. Setup runs bundled PowerShell scripts behind the scenes with a process-scoped RemoteSigned policy. It does not change saved execution policy or override Group Policy. Uninstall retains runtime settings, encrypted credentials, backups, and qBittorrent preferences.

Release validation includes PowerShell 5.1/7 tests and an isolated Windows runner test of fresh install, credential-preserving upgrade, and native uninstall.
