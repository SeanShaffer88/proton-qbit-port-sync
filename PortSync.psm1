Set-StrictMode -Version 2

function Get-ProtonForwardedPort {
    param([string[]]$Lines, [datetimeoffset]$Now = [datetimeoffset]::UtcNow, [int]$MaxAgeSeconds = 90)
    $line = $Lines | Where-Object { $_ -match 'Port.*Forwarding.*Status|Port pair' } | Select-Object -Last 1
    if (!$line -or $line -notmatch '^(\S+).*Status ''SleepingUntilRefresh''.*Port pair (\d+)->(\d+)') { return $null }
    $stamp = [datetimeoffset]::MinValue
    if (![datetimeoffset]::TryParse($Matches[1], [ref]$stamp)) { return $null }
    $inside = 0; $outside = 0
    if (![int]::TryParse($Matches[2], [ref]$inside) -or ![int]::TryParse($Matches[3], [ref]$outside)) { return $null }
    $age = ($Now - $stamp).TotalSeconds
    if ($age -lt -10 -or $age -gt $MaxAgeSeconds -or $inside -ne $outside -or $outside -lt 1 -or $outside -gt 65535) { return $null }
    return $outside
}

function Set-IniValues {
    param([string]$Text, [string]$Section, [System.Collections.IDictionary]$Values)
    $lines = [Collections.Generic.List[string]]::new()
    foreach ($line in ($Text -split '\r?\n')) { $lines.Add($line) }
    $start = -1; $end = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -eq "[$Section]") { $start = $i; continue }
        if ($start -ge 0 -and $lines[$i] -match '^\[') { $end = $i; break }
    }
    if ($start -lt 0) { $lines.Add("[$Section]"); $start = $lines.Count - 1; $end = $lines.Count }
    foreach ($key in $Values.Keys) {
        $found = $false
        for ($i = $end - 1; $i -gt $start; $i--) {
            if ($lines[$i].StartsWith("$key=")) {
                if (!$found) { $lines[$i] = "$key=$($Values[$key])"; $found = $true }
                else { $lines.RemoveAt($i); $end-- }
            }
        }
        if (!$found) { $lines.Insert($end, "$key=$($Values[$key])"); $end++ }
    }
    return ($lines -join "`r`n")
}

function Get-IniValue {
    param([string]$Text, [string]$Section, [string]$Key)
    $inside = $false
    foreach ($line in ($Text -split '\r?\n')) {
        if ($line -match '^\[') { $inside = $line -eq "[$Section]" }
        elseif ($inside -and $line.StartsWith("$Key=")) { return $line.Substring($Key.Length + 1) }
    }
    return $null
}

function Invoke-QbitPortSync {
    param([string]$BaseUrl, [pscredential]$Credential, [int]$Port, [string]$ExpectedInterface)
    $uri = [uri]$BaseUrl
    if ($uri.Scheme -ne 'http' -or $uri.Host -ne '127.0.0.1' -or $uri.AbsolutePath -ne '/') { throw 'Only an HTTP API on 127.0.0.1 is supported.' }
    if ($Port -lt 1 -or $Port -gt 65535) { throw 'Invalid torrent port.' }
    $headers = @{ Referer = "$BaseUrl/" }
    $session = $null
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/api/v2/auth/login" -Method Post -Headers $headers -Body @{ username = $Credential.UserName; password = $Credential.GetNetworkCredential().Password } -SessionVariable session -TimeoutSec 5
        $loginText = $response.Content
        if ($loginText -is [byte[]]) { $loginText = [Text.Encoding]::UTF8.GetString($loginText) }
        if ($response.StatusCode -ne 204 -and ([string]::IsNullOrWhiteSpace($loginText) -or $loginText.Trim() -ne 'Ok.')) { throw 'qBittorrent API authentication failed.' }
        $prefs = Invoke-RestMethod -Uri "$BaseUrl/api/v2/app/preferences" -Headers $headers -WebSession $session -TimeoutSec 5
        if ([string]::IsNullOrWhiteSpace($ExpectedInterface) -or $prefs.current_network_interface -ne $ExpectedInterface) { throw 'VPN interface binding changed; refusing to update.' }
        $changed = $prefs.listen_port -ne $Port -or $prefs.upnp -or $prefs.random_port
        if ($changed) {
            $json = @{ listen_port = $Port; upnp = $false; random_port = $false } | ConvertTo-Json -Compress
            Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/api/v2/app/setPreferences" -Method Post -Headers $headers -WebSession $session -Body @{ json = $json } -TimeoutSec 5 | Out-Null
            $verify = Invoke-RestMethod -Uri "$BaseUrl/api/v2/app/preferences" -Headers $headers -WebSession $session -TimeoutSec 5
            if ($verify.listen_port -ne $Port -or $verify.upnp -or $verify.random_port -or $verify.current_network_interface -ne $ExpectedInterface) { throw 'Port/binding verification failed.' }
        }
        return [bool]$changed
    } finally {
        if ($session) { try { Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/api/v2/auth/logout" -Method Post -Headers $headers -WebSession $session -TimeoutSec 5 | Out-Null } catch {} }
    }
}

Export-ModuleMember -Function Get-ProtonForwardedPort, Set-IniValues, Get-IniValue, Invoke-QbitPortSync
