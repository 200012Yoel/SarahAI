# ============================================================
# Sarah AI - Script de Téléchargement Automatique de l'IPA
# ============================================================

$repo = "200012Yoel/SarahAI"
$destDir = "dist"
$destFile = "dist\SarahIA.ipa"

if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SARAH AI - Telechargement de l'IPA" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$releaseUrl = "https://github.com/$repo/releases/download/latest/SarahIA.ipa"
$actionsUrl = "https://github.com/$repo/actions"
$releasesPage = "https://github.com/$repo/releases"

Write-Host "Attente et telechargement du fichier IPA valide..." -ForegroundColor Yellow

$maxAttempts = 20
$attempt = 1
$downloadSuccess = $false

while ($attempt -le $maxAttempts -and -not $downloadSuccess) {
    Write-Host "  [Tentative $attempt/$maxAttempts] Verification de la disponibilite de SarahIA.ipa..." -ForegroundColor Yellow
    
    # Supprimer l'ancien fichier s'il est corrompu ou incomplet
    if (Test-Path $destFile) {
        $size = (Get-Item $destFile).Length
        if ($size -lt 50000) {
            Remove-Item -Path $destFile -Force -ErrorAction SilentlyContinue
        } else {
            $downloadSuccess = $true
            break
        }
    }
    
    try {
        curl.exe -L -f -s -o $destFile $releaseUrl
        if (Test-Path $destFile) {
            $size = (Get-Item $destFile).Length
            if ($size -gt 50000) {
                $downloadSuccess = $true
                break
            } else {
                Remove-Item -Path $destFile -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        # En attente de compilation
    }
    
    Write-Host "  -> Compilation macOS en cours... Nouvelle tentative dans 12s..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 12
    $attempt++
}

if ($downloadSuccess -and (Test-Path $destFile)) {
    $finalSizeMB = [math]::Round((Get-Item $destFile).Length / 1MB, 2)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "  [SUCCES TOTAL] Fichier IPA complet telecharge !" -ForegroundColor Green
    Write-Host "  -> Emplacement : $destFile" -ForegroundColor Green
    Write-Host "  -> Taille du binaire : $finalSizeMB Mo" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Instructions pour l'installer sur votre iPhone :" -ForegroundColor Cyan
    Write-Host "1. Branchez votre iPhone en USB sur votre PC." -ForegroundColor White
    Write-Host "2. Ouvrez Sideloadly (ou AltStore)." -ForegroundColor White
    Write-Host "3. Glissez le fichier '$destFile' dans Sideloadly et cliquez sur 'Start'." -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "  [INFO] Telechargez l'IPA directement depuis votre navigateur :" -ForegroundColor Yellow
    Write-Host "  -> $releasesPage" -ForegroundColor Cyan
    Write-Host "  -> $actionsUrl" -ForegroundColor Cyan
    Write-Host ""
}
