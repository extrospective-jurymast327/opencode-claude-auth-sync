$ErrorActionPreference = "Stop"

$claudeCredsPath = if ($env:CLAUDE_CREDENTIALS_PATH) { $env:CLAUDE_CREDENTIALS_PATH } else { Join-Path $HOME ".claude\.credentials.json" }
$opencodeAuthPath = if ($env:OPENCODE_AUTH_PATH) { $env:OPENCODE_AUTH_PATH } else { Join-Path $HOME ".local\share\opencode\auth.json" }

if (-not (Test-Path $claudeCredsPath)) { exit 0 }
if (-not (Test-Path $opencodeAuthPath)) { exit 0 }

$claudeRaw = Get-Content $claudeCredsPath -Raw | ConvertFrom-Json
$creds = if ($claudeRaw.claudeAiOauth) { $claudeRaw.claudeAiOauth } else { $claudeRaw }

if (-not $creds.accessToken -or -not $creds.refreshToken -or -not $creds.expiresAt) {
    Write-Error "Claude credentials incomplete"
    exit 1
}

$auth = Get-Content $opencodeAuthPath -Raw | ConvertFrom-Json

$remaining = $creds.expiresAt - [long]([datetime]::UtcNow - [datetime]::new(1970, 1, 1)).TotalMilliseconds
$hours = [math]::Floor($remaining / 3600000)
$mins = [math]::Floor(($remaining % 3600000) / 60000)
$status = if ($remaining -gt 0) { "${hours}h ${mins}m remaining" } else { "EXPIRED" }

if ($auth.anthropic -and $auth.anthropic.access -eq $creds.accessToken -and $auth.anthropic.refresh -eq $creds.refreshToken) {
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

$auth | ConvertTo-Json -Depth 10 | Set-Content $opencodeAuthPath -Encoding UTF8
Write-Output "$(Get-Date -Format o) synced ($status)"
