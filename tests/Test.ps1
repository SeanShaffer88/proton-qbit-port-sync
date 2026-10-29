$ErrorActionPreference = 'Stop'
$module = Import-Module (Join-Path $PSScriptRoot '..\PortSync.psm1') -Force -PassThru
$script:checks = 0
function Assert($condition, [string]$message) { if (!$condition) { throw $message }; $script:checks++ }
$now = [datetimeoffset]::UtcNow
$valid = $now.ToString('o') + " | INFO | Port Forwarding state changed - Status 'SleepingUntilRefresh', Port pair 50797->50797"
Assert ((Get-ProtonForwardedPort @($valid) $now) -eq 50797) 'Valid lease rejected'
foreach ($invalid in @(
    $valid.Replace('SleepingUntilRefresh','Error'),
    $valid.Replace('SleepingUntilRefresh','PortMappingCommunication'),
    $valid.Replace('50797->50797','50797->50000'),
    $valid.Replace('50797','70000'),
    $valid.Replace('50797','0'),
    $valid.Replace($now.ToString('o'),'not-a-date'),
    $valid.Replace('50797','999999999999999999999')
)) { Assert ($null -eq (Get-ProtonForwardedPort @($invalid) $now)) 'Invalid lease accepted' }
Assert ($null -eq (Get-ProtonForwardedPort @($valid) $now.AddSeconds(100))) 'Stale lease accepted'
Assert ($null -eq (Get-ProtonForwardedPort @($valid) $now.AddSeconds(-30))) 'Future lease accepted'
Assert ($null -eq (Get-ProtonForwardedPort @($valid, ($now.ToString('o') + " | Received PortForwarding Status 'Error'")) $now)) 'Error after valid lease ignored'
Assert ($null -eq (Get-ProtonForwardedPort @() $now)) 'Empty log accepted'
$ini = "[BitTorrent]`nSession\Interface=test-vpn`nSession\Port=12345`n[Preferences]`nWebUI\Enabled=false`n[Other]`nKeep=unchanged"
$edited = Set-IniValues $ini 'Preferences' ([ordered]@{ 'WebUI\Enabled'='true'; 'WebUI\Port'='18765' })
Assert ((Get-IniValue $edited 'Preferences' 'WebUI\Enabled') -eq 'true') 'INI update failed'
Assert ((Get-IniValue $edited 'Preferences' 'WebUI\Port') -eq '18765') 'INI insertion failed'
Assert ((Get-IniValue $edited 'Other' 'Keep') -eq 'unchanged') 'Unrelated INI setting changed'
Assert ((Get-IniValue $edited 'BitTorrent' 'Session\Interface') -eq 'test-vpn') 'VPN binding changed'
$newSection = Set-IniValues '' 'Preferences' @{ 'WebUI\Enabled'='true' }
Assert ((Get-IniValue $newSection 'Preferences' 'WebUI\Enabled') -eq 'true') 'New INI section failed'
$duplicate = Set-IniValues "[Preferences]`nA=1`nA=2" 'Preferences' @{ A='3' }
Assert ((@($duplicate -split '\r?\n' | Where-Object { $_ -match '^A=' })).Count -eq 1) 'Duplicate INI keys retained'

# Exercise the API transaction without a real torrent client or credentials.
& $module {
    $script:apiPrefs = [pscustomobject]@{ listen_port=12345; upnp=$true; random_port=$true; current_network_interface='test-vpn' }
    $script:updates = 0; $script:logout = 0; $script:logins = 0
    function script:Invoke-WebRequest {
        param($Uri,$Method,$Headers,$Body,$SessionVariable,$WebSession,$TimeoutSec,[switch]$UseBasicParsing)
        if ($Uri -like '*/auth/login') {
            if ($Body.username -ne 'test-user' -or $Headers.Referer -ne 'http://127.0.0.1:18765/') { throw 'Bad login request' }
            Set-Variable -Name $SessionVariable -Value @{} -Scope 1
            $script:logins++
            if ($script:logins -eq 1) { return [pscustomobject]@{ StatusCode=200; Content=[Text.Encoding]::UTF8.GetBytes('Ok.') } }
            return [pscustomobject]@{ StatusCode=204; Content=[byte[]]@() }
        }
        if ($Uri -like '*/setPreferences') {
            $payload = $Body.json | ConvertFrom-Json
            $script:apiPrefs.listen_port=$payload.listen_port
            $script:apiPrefs.upnp=$payload.upnp; $script:apiPrefs.random_port=$payload.random_port
            $script:updates++; return [pscustomobject]@{ Content='' }
        }
        if ($Uri -like '*/auth/logout') { $script:logout++; return [pscustomobject]@{ Content='' } }
        throw 'Unexpected endpoint'
    }
    function script:Invoke-RestMethod { param($Uri,$Headers,$WebSession,$TimeoutSec); return $script:apiPrefs }
    $cred = [pscredential]::new('test-user',(ConvertTo-SecureString 'test-only' -AsPlainText -Force))
    if (!(Invoke-QbitPortSync 'http://127.0.0.1:18765' $cred 50797 'test-vpn')) { throw 'API update did not report change' }
    if ($script:updates -ne 1 -or $script:apiPrefs.listen_port -ne 50797 -or $script:apiPrefs.upnp -or $script:apiPrefs.random_port) { throw 'API update failed' }
    if (Invoke-QbitPortSync 'http://127.0.0.1:18765' $cred 50797 'test-vpn') { throw 'Unchanged port caused update' }
    $script:apiPrefs.current_network_interface='other-vpn'
    $rejected = $false
    try { Invoke-QbitPortSync 'http://127.0.0.1:18765' $cred 50000 'test-vpn' } catch { $rejected = $_.Exception.Message -like '*binding changed*' }
    if (!$rejected -or $script:updates -ne 1) { throw 'Binding change was not blocked' }
    if ($script:logout -ne 3) { throw 'API sessions were not logged out' }
    $rejected = $false
    try { Invoke-QbitPortSync 'http://192.0.2.1:18765' $cred 50000 'test-vpn' } catch { $rejected = $true }
    if (!$rejected) { throw 'Nonlocal API accepted' }
}
$script:checks += 5
$releaseOutput = Join-Path ([IO.Path]::GetTempPath()) ('proton-qbit-test-' + [guid]::NewGuid().ToString('N'))
& (Join-Path $PSScriptRoot '..\Build-Release.ps1') -Version '0.1.0' -OutputDirectory $releaseOutput | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPath = Join-Path $releaseOutput 'proton-qbit-port-sync-0.1.0-windows.zip'
$archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $entries = @($archive.Entries | ForEach-Object FullName)
    Assert ($entries.Count -eq 8) 'Unexpected release file count'
    foreach ($required in @('Install.cmd','Setup.ps1','Install.ps1','Watch-Port.ps1','Uninstall.ps1','PortSync.psm1','README.md','LICENSE')) {
        Assert ($entries -contains $required) "Missing packaged file: $required"
    }
    Assert (!($entries | Where-Object { $_ -match '(credential|config\.json|\.log$|\.ini$|\.git/)' })) 'Private runtime files packaged'
} finally { $archive.Dispose() }
$checksum = Get-Content -LiteralPath (Join-Path $releaseOutput 'SHA256SUMS.txt') -Raw
Assert ($checksum.StartsWith((Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLowerInvariant())) 'Release checksum mismatch'
Get-ChildItem (Join-Path $PSScriptRoot '..') -Recurse -File | Where-Object Extension -in '.ps1','.psm1' | ForEach-Object {
    $tokens=$null; $errors=$null
    [Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors) | Out-Null
    if ($errors.Count) { throw ($_.Name + ': ' + ($errors.Message -join '; ')) }
    $script:checks++
}
Write-Output "Passed $script:checks checks (lease parsing, INI preservation, API transactions, and PowerShell syntax)."
