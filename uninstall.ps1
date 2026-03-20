$ErrorActionPreference = "Stop"

$installDir = Join-Path $HOME ".local\bin"
$scriptName = "sync-claude-to-opencode.ps1"
$taskName = "SyncClaudeToOpenCode"

Write-Output "==> Removing Task Scheduler job..."
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Output "    Task removed."
} else {
    Write-Output "    No task found. Skipping."
}

Write-Output "==> Removing sync script..."
$scriptPath = Join-Path $installDir $scriptName
if (Test-Path $scriptPath) {
    Remove-Item $scriptPath
    Write-Output "    Script removed."
} else {
    Write-Output "    Script not found. Skipping."
}

Write-Output ""
Write-Output "Done. OpenCode auth.json was not modified."
