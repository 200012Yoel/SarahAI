param(
    [int]$MaxMinutes = 15
)

$startTime = Get-Date
Write-Host "Monitoring GitHub Actions build for commit 842c753..."

while (((Get-Date) - $startTime).TotalMinutes -lt $MaxMinutes) {
    try {
        $runs = Invoke-RestMethod -Uri "https://api.github.com/repos/200012Yoel/SarahAI/actions/runs?per_page=5" -Headers @{ "User-Agent" = "PowerShell" }
        $latestRun = $runs.workflow_runs | Where-Object { $_.head_sha -eq "842c7537b02553b3fbdb555b7226f94793f412d2" -or $_.head_branch -eq "main" } | Select-Object -First 1
        
        if ($latestRun) {
            $status = $latestRun.status
            $conclusion = $latestRun.conclusion
            $runId = $latestRun.id
            $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
            Write-Host "[$elapsed s] Run ID: $runId | Status: $status | Conclusion: $conclusion | Commit: $($latestRun.head_commit.id.Substring(0,7)) - $($latestRun.head_commit.message)"
            
            if ($status -eq "completed") {
                if ($conclusion -eq "success") {
                    Write-Host "✅ Build succeeded!"
                    exit 0
                } else {
                    Write-Host "❌ Build failed with conclusion: $conclusion"
                    exit 1
                }
            }
        }
    } catch {
        Write-Host "Error fetching runs: $_"
    }
    Start-Sleep -Seconds 15
}

Write-Host "Timed out waiting for build."
exit 2
