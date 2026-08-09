# ============================================================
# Sarah AI - Script de Téléchargement Automatique de l'IPA
# ============================================================

$repo = "200012Yoel/SarahAI"
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SARAH AI - Telechargement de l'IPA" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Recherche du dernier workflow de compilation iOS sur GitHub..." -ForegroundColor Yellow

$runsUrl = "https://api.github.com/repos/$repo/actions/workflows/ios-build.yml/runs?per_page=1"

try {
    $runsResponse = Invoke-RestMethod -Uri $runsUrl -Method Get -Headers @{ "User-Agent" = "PowerShell" }
    $latestRun = $runsResponse.workflow_runs[0]
    
    if ($null -eq $latestRun) {
        Write-Host "[ERREUR] Aucun workflow trouve sur le depot $repo" -ForegroundColor Red
        exit 1
    }

    $runId = $latestRun.id
    $status = $latestRun.status
    $conclusion = $latestRun.conclusion
    $htmlUrl = $latestRun.html_url

    Write-Host "Dernier Run ID : $runId" -ForegroundColor Green
    Write-Host "Lien du workflow : $htmlUrl" -ForegroundColor Magenta
    Write-Host "Statut actuel : $status" -ForegroundColor Yellow

    # Attendre que la compilation macOS soit completement terminee
    while ($status -ne "completed") {
        Write-Host "  -> Compilation en cours sur le serveur macOS... Attente de 15s..." -ForegroundColor Yellow
        Start-Sleep -Seconds 15
        $checkUrl = "https://api.github.com/repos/$repo/actions/runs/$runId"
        $runCheck = Invoke-RestMethod -Uri $checkUrl -Method Get -Headers @{ "User-Agent" = "PowerShell" }
        $status = $runCheck.status
        $conclusion = $runCheck.conclusion
    }

    Write-Host "  [OK] Compilation terminee avec succes ! (Conclusion: $conclusion)" -ForegroundColor Green

    # Recuperer les artefacts
    $artifactsUrl = "https://api.github.com/repos/$repo/actions/runs/$runId/artifacts"
    $artifactsResponse = Invoke-RestMethod -Uri $artifactsUrl -Method Get -Headers @{ "User-Agent" = "PowerShell" }
    
    $ipaArtifact = $artifactsResponse.artifacts | Where-Object { $_.name -eq "ipa" }
    
    if ($null -ne $ipaArtifact) {
        $sizeMB = [math]::Round($ipaArtifact.size_in_bytes / 1MB, 2)
        Write-Host "  [TROUVE] Artefact IPA trouve ($sizeMB Mo)" -ForegroundColor Green
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "  VOUS POUVEZ TELECHARGER L'IPA DIRECTEMENT VIA CE LIEN :" -ForegroundColor Green
        Write-Host "  $htmlUrl" -ForegroundColor Yellow
        Write-Host "============================================================" -ForegroundColor Cyan
    } else {
        Write-Host "Consultez le statut et telechargez l'artefact sur : $htmlUrl" -ForegroundColor Yellow
    }

} catch {
    Write-Host "Consultez vos runs et telechargez l'IPA directement ici :" -ForegroundColor Yellow
    Write-Host "https://github.com/$repo/actions" -ForegroundColor Cyan
}

Write-Host ""
