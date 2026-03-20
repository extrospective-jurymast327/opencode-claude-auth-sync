$ErrorActionPreference = "Stop"

$installDir = Join-Path $HOME ".local\bin"
$scriptName = "sync-claude-to-opencode.ps1"
$repoRaw = "https://raw.githubusercontent.com/lehdqlsl/opencode-claude-auth-sync/main"

$claudeCreds = Join-Path $HOME ".claude\.credentials.json"
$opencodeAuth = Join-Path $HOME ".local\share\opencode\auth.json"

Write-Output "==> Checking prerequisites..."

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: node is required but not found"; exit 1
}
if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: opencode is required but not found"; exit 1
}
if (-not (Test-Path $claudeCreds)) {
    Write-Error "ERROR: Claude credentials not found at $claudeCreds`nRun 'claude' first to authenticate."
    exit 1
}
if (-not (Test-Path $opencodeAuth)) {
    Write-Error "ERROR: OpenCode auth file not found at $opencodeAuth`nRun 'opencode' at least once first."
    exit 1
}

Write-Output "==> Installing sync script to $installDir\$scriptName..."
New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Invoke-WebRequest -Uri "$repoRaw/$scriptName" -OutFile "$installDir\$scriptName"

Write-Output "==> Running initial sync..."
try {
    & powershell -ExecutionPolicy Bypass -File "$installDir\$scriptName"
    Write-Output "    Initial sync complete."
} catch {
    Write-Output "    Initial sync skipped."
}

Write-Output "==> Removing opencode-claude-auth from opencode.json if present..."
$opencodeConfig = Join-Path $HOME ".config\opencode\opencode.json"
if (Test-Path $opencodeConfig) {
    $config = Get-Content $opencodeConfig -Raw | ConvertFrom-Json
    if ($config.plugin -and ($config.plugin -match "opencode-claude-auth")) {
        $config.plugin = @($config.plugin | Where-Object { $_ -notmatch "opencode-claude-auth" })
        $config | ConvertTo-Json -Depth 10 | Set-Content $opencodeConfig -Encoding UTF8
        Write-Output "    Removed opencode-claude-auth from plugin list."
    }
}

Write-Output "==> Setting up Task Scheduler (every hour)..."
$taskName = "SyncClaudeToOpenCode"
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-Output "    Task already registered. Skipping."
} else {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$installDir\$scriptName`""
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Sync Claude CLI credentials to OpenCode" | Out-Null
    Write-Output "    Task Scheduler registered."
}

Write-Output ""
Write-Output "Done! Verify with:"
Write-Output "  opencode providers list    # Should show: Anthropic oauth"
Write-Output "  opencode models anthropic  # Should list Claude models"
