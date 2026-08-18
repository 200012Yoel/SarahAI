param (
    [Parameter(Mandatory=$true)]
    [string]$Type # "apk" or "ipa"
)

$repo = "200012Yoel/SarahAI"
$fileName = if ($Type -eq "apk") { "SarahIA.apk" } else { "SarahIA.ipa" }
$targetPath = Join-Path (Get-Location) $fileName
$releaseUrl = "https://github.com/$repo/releases/download/latest/$fileName"
$apiUrl = "https://api.github.com/repos/$repo/releases/latest"

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "  ⏳ ATTENTE ET TELECHARGEMENT AUTOMATIQUE DU FICHIER" -ForegroundColor Cyan
Write-Host "  Fichier attendu : $fileName" -ForegroundColor Yellow
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

$maxWaitSeconds = 600 # 10 minutes max
$interval = 6
$elapsed = 0

Write-Host "Le serveur compile actuellement votre application..." -ForegroundColor Gray
Write-Host "Telechargement automatique des que le build est termine." -ForegroundColor Gray
Write-Host ""

while ($elapsed -lt $maxWaitSeconds) {
    $secondsLeft = $maxWaitSeconds - $elapsed
    Write-Host -NoNewline "`r[En attente du binaire...] $($elapsed)s ecoulees (Verification en cours...)   "
    
    try {
        # Verifier si la release est prete via curl
        $testHeader = curl.exe -sI -L "$releaseUrl" | Select-String "HTTP/" | Select-Object -Last 1
        
        if ($testHeader -match "200 OK") {
            Write-Host ""
            Write-Host "`n[1/2] Binaire detecte ! Telechargement en cours..." -ForegroundColor Green
            
            # Telechargement direct avec curl avec barre de progression
            curl.exe -L -o "$targetPath" "$releaseUrl" --progress-bar
            
            if (Test-Path "$targetPath") {
                $size = (Get-Item "$targetPath").Length
                if ($size -gt 100000) {
                    $sizeMB = [math]::Round($size / 1MB, 2)
                    Write-Host ""
                    Write-Host "=======================================================" -ForegroundColor Green
                    Write-Host "  🎉 $fileName TELECHARGE AVEC SUCCES DANS VOS DOSSIERS !" -ForegroundColor Green
                    Write-Host "  Emplacement : $targetPath ($sizeMB Mo)" -ForegroundColor Yellow
                    Write-Host "=======================================================" -ForegroundColor Green
                    Write-Host ""
                    
                    # Ouvrir et selectionner le fichier directement dans l'explorateur Windows
                    explorer.exe /select,"$targetPath"
                    exit 0
                }
            }
        }
    } catch {
        # Continuer d'attendre
    }
    
    Start-Sleep -Seconds $interval
    $elapsed += $interval
}

Write-Host ""
Write-Host "⚠️ Temps d'attente depasse. Vous pouvez recuperer le fichier directement ici :" -ForegroundColor Yellow
Write-Host "https://github.com/$repo/releases" -ForegroundColor Cyan
