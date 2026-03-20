$ErrorActionPreference = "Stop"

$claudeCredsPath = if ($env:CLAUDE_CREDENTIALS_PATH) { $env:CLAUDE_CREDENTIALS_PATH } else { Join-Path $HOME ".claude\.credentials.json" }
$opencodeAuthPath = if ($env:OPENCODE_AUTH_PATH) { $env:OPENCODE_AUTH_PATH } else { Join-Path $HOME ".local\share\opencode\auth.json" }

if (-not (Test-Path $claudeCredsPath)) { exit 0 }
if (-not (Test-Path $opencodeAuthPath)) { exit 0 }

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

try {
    $claudeRaw = Get-Content $claudeCredsPath -Raw | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse Claude credentials: $_"
    exit 1
}

$creds = if ($claudeRaw.claudeAiOauth) { $claudeRaw.claudeAiOauth } else { $claudeRaw }

if (-not $creds.accessToken -or -not $creds.refreshToken -or -not $creds.expiresAt) {
    Write-Error "Claude credentials incomplete"
    exit 1
}

try {
    $auth = Get-Content $opencodeAuthPath -Raw | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse ${opencodeAuthPath}: $_"
    exit 1
}

$remaining = $creds.expiresAt - [long]([datetime]::UtcNow - [datetime]::new(1970, 1, 1)).TotalMilliseconds
$hours = [math]::Floor($remaining / 3600000)
$mins = [math]::Floor(($remaining % 3600000) / 60000)
$status = if ($remaining -gt 0) { "${hours}h ${mins}m remaining" } else { "EXPIRED" }

if ($auth.anthropic -and
    $auth.anthropic.access -eq $creds.accessToken -and
    $auth.anthropic.refresh -eq $creds.refreshToken -and
    $auth.anthropic.expires -eq $creds.expiresAt) {
    Write-Output "$(Get-Date -Format o) already in sync ($status)"
    exit 0
}

if (-not $auth.anthropic) {
    $auth | Add-Member -NotePropertyName "anthropic" -NotePropertyValue ([PSCustomObject]@{}) -Force
}

$auth.anthropic = [PSCustomObject]@{
    type    = "oauth"
    access  = $creds.accessToken
    refresh = $creds.refreshToken
    expires = $creds.expiresAt
}

# Atomic write: temp file then move
$tmpPath = "$opencodeAuthPath.tmp.$PID"
try {
    $json = $auth | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($tmpPath, $json, $utf8NoBom)
    Move-Item -Path $tmpPath -Destination $opencodeAuthPath -Force
} catch {
    if (Test-Path $tmpPath) { Remove-Item $tmpPath -ErrorAction SilentlyContinue }
    throw
}
Write-Output "$(Get-Date -Format o) synced ($status)"
