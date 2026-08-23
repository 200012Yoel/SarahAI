param (
    [Parameter(Mandatory=$true)]
    [string]$Type # "apk" or "ipa"
)

$repo = "200012Yoel/SarahAI"

$fileName = switch ($Type) {
    "apk" { "SarahIA.apk" }
    Default { "SarahIA.ipa" }
}

$targetPath = Join-Path (Get-Location) $fileName
if (Test-Path "$targetPath") {
    try { Remove-Item "$targetPath" -Force } catch {}
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  ⏳ ATTENTE DU BUILD GITHUB ACTIONS ET TELECHARGEMENT DE L'IPA" -ForegroundColor Cyan
Write-Host "  Fichier : $fileName (Compatible iOS 12.0+ / iPhone 5S / 6 / 7)" -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$maxWaitSeconds = 900 # 15 minutes
$interval = 6
$elapsed = 0

Write-Host "Vérification en temps réel de la compilation sur macOS..." -ForegroundColor Gray

# Récupération du commit local actuel
$currentHead = (git rev-parse HEAD 2>$null)
if ($currentHead) {
    $currentHead = $currentHead.Trim()
}

while ($elapsed -lt $maxWaitSeconds) {
    Write-Host -NoNewline "`r[Compilation macOS en cours...] $($elapsed)s écoulées...              "
    
    try {
        # 1. Vérifier si un nouveau workflow a terminé
        $headers = @{ "User-Agent" = "PowerShell-Downloader" }
        $apiUrl = "https://api.github.com/repos/$repo/actions/runs?per_page=5"
        $runsResponse = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10 -ErrorAction SilentlyContinue
        
        if ($runsResponse -and $runsResponse.workflow_runs) {
            $matchingRuns = $runsResponse.workflow_runs | Where-Object { 
                ($_.name -like "*$Type*" -or $_.name -like "*iOS*" -or $_.name -like "*Android*")
            }
            $targetRun = $matchingRuns | Where-Object { $_.head_sha -eq $currentHead } | Select-Object -First 1
            if (-not $targetRun -and $elapsed -lt 90) {
                # Le run n'a pas encore démarré sur GitHub, continuer à attendre
                Start-Sleep -Seconds $interval
                $elapsed += $interval
                continue
            }
            $latestRun = if ($targetRun) { $targetRun } else { $matchingRuns | Select-Object -First 1 }
            if (-not $latestRun) { $latestRun = $runsResponse.workflow_runs[0] }
            
            if ($latestRun.status -eq "completed") {
                if ($latestRun.conclusion -eq "success") {
                    Write-Host ""
                    Write-Host "  ✅ Compilation GitHub Actions terminée avec succès !" -ForegroundColor Green
                    Write-Host "  Téléchargement du binaire $fileName..." -ForegroundColor Cyan
                    
                    $directDownloadUrl = "https://github.com/$repo/releases/latest/download/$fileName"
                    $tempOutput = Join-Path (Get-Location) "temp_$fileName"
                    if (Test-Path "$tempOutput") { Remove-Item "$tempOutput" -Force }
                    
                    # Téléchargement via curl
                    & curl.exe -s -L -f -o "$tempOutput" "$directDownloadUrl"
                    
                    if ((Test-Path "$tempOutput") -and ((Get-Item "$tempOutput").Length -gt 100000)) {
                        Move-Item -Path "$tempOutput" -Destination "$targetPath" -Force
                        $size = (Get-Item "$targetPath").Length
                        $sizeMB = [math]::Round($size / 1MB, 2)
                        
                        Write-Host ""
                        Write-Host "==================================================================" -ForegroundColor Green
                        Write-Host "  🎉 $fileName PRET POUR L'INSTALLATION SUR IPHONE 5S / 6 / 7 !" -ForegroundColor Green
                        Write-Host "  Fichier : $targetPath ($sizeMB Mo)" -ForegroundColor Yellow
                        Write-Host "  Vous pouvez maintenant cliquer sur 'Start' dans Sideloadly !" -ForegroundColor Cyan
                        Write-Host "==================================================================" -ForegroundColor Green
                        Write-Host ""
                        
                        explorer.exe /select,"$targetPath"
                        exit 0
                    }
                } elseif ($latestRun.conclusion -eq "failure") {
                    Write-Host ""
                    Write-Host "❌ Le build sur GitHub Actions a échoué. Consultez les logs : $($latestRun.html_url)" -ForegroundColor Red
                    exit 1
                }
            }
        }
    } catch {
        # Continuer
    }
    
    Start-Sleep -Seconds $interval
    $elapsed += $interval
}

Write-Host ""
Write-Host "⚠️ Temps d'attente dépassé. Vous pouvez vérifier le statut ici :" -ForegroundColor Yellow
Write-Host "https://github.com/$repo/actions" -ForegroundColor Cyan
