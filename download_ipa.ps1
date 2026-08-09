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

Write-Host "Verification et telechargement de l'IPA depuis la derniere Release GitHub..." -ForegroundColor Yellow

try {
    # Telechargement direct avec curl.exe (suit les redirections GitHub automatiquement)
    curl.exe -L -f -o $destFile $releaseUrl
    
    if (Test-Path $destFile) {
        $sizeBytes = (Get-Item $destFile).Length
        if ($sizeBytes -gt 50000) {
            $sizeMB = [math]::Round($sizeBytes / 1MB, 2)
            Write-Host ""
            Write-Host "  [SUCCES TOTAL] Fichier IPA complet telecharge avec succes !" -ForegroundColor Green
            Write-Host "  -> Emplacement : $destFile" -ForegroundColor Green
            Write-Host "  -> Taille : $sizeMB Mo" -ForegroundColor Green
            Write-Host ""
            Write-Host "Pour l'installer sur votre iPhone :" -ForegroundColor Cyan
            Write-Host "1. Ouvrez Sideloadly (ou AltStore) sur votre PC." -ForegroundColor White
            Write-Host "2. Glissez-deposez le fichier '$destFile' dans Sideloadly." -ForegroundColor White
            Write-Host "3. Cliquez sur 'Start' pour installer Sarah AI sur votre iPhone !" -ForegroundColor White
            Write-Host ""
            exit 0
        } else {
            Remove-Item -Path $destFile -Force -ErrorAction SilentlyContinue
        }
    }
} catch {
    # Ignorer si la release est en cours de generation
}

Write-Host "  [INFO] La compilation est en cours de finalisation sur GitHub Actions." -ForegroundColor Yellow
Write-Host "  -> Suivre la compilation : $actionsUrl" -ForegroundColor Cyan
Write-Host "  -> Page des Releases : $releasesPage" -ForegroundColor Cyan
Write-Host ""
