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
$directDownloadUrl = "https://github.com/$repo/releases/latest/download/$fileName"
$fallbackDownloadUrl = "https://github.com/$repo/releases/download/latest/$fileName"

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  ⏳ ATTENTE ET TELECHARGEMENT AUTOMATIQUE DU FICHIER" -ForegroundColor Cyan
Write-Host "  Fichier attendu : $fileName" -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$maxWaitSeconds = 900 # 15 minutes max
$interval = 8
$elapsed = 0

Write-Host "Le serveur compile actuellement votre application pour iPhone 5S sur macOS..." -ForegroundColor Gray
Write-Host "Telechargement automatique des que le build est termine." -ForegroundColor Gray
Write-Host ""

while ($elapsed -lt $maxWaitSeconds) {
    $secondsLeft = $maxWaitSeconds - $elapsed
    Write-Host -NoNewline "`r[En attente du binaire...] $($elapsed)s ecoulees (Verification de la release...)   "
    
    try {
        $tempOutput = Join-Path (Get-Location) "temp_$fileName"
        if (Test-Path "$tempOutput") { Remove-Item "$tempOutput" -Force }
        
        # Tentative 1: URL directe
        $curlResult = & curl.exe -s -L -f -o "$tempOutput" "$directDownloadUrl" 2>&1
        
        # Tentative 2 si échoue: URL générique
        if (-not (Test-Path "$tempOutput") -or ((Get-Item "$tempOutput").Length -lt 100000)) {
            if ($Type -eq "ipa-legacy") {
                $curlResult = & curl.exe -s -L -f -o "$tempOutput" "$genericLegacyUrl" 2>&1
            }
        }
        
        if ((Test-Path "$tempOutput") -and ((Get-Item "$tempOutput").Length -gt 100000)) {
            if (Test-Path "$targetPath") { Remove-Item "$targetPath" -Force }
            Move-Item -Path "$tempOutput" -Destination "$targetPath" -Force
            
            $size = (Get-Item "$targetPath").Length
            $sizeMB = [math]::Round($size / 1MB, 2)
            Write-Host ""
            Write-Host "==================================================================" -ForegroundColor Green
            Write-Host "  🎉 $fileName TELECHARGE AVEC SUCCES DANS VOS DOSSIERS !" -ForegroundColor Green
            Write-Host "  Emplacement : $targetPath ($sizeMB Mo)" -ForegroundColor Yellow
            Write-Host "==================================================================" -ForegroundColor Green
            Write-Host ""
            
            explorer.exe /select,"$targetPath"
            exit 0
        } else {
            if (Test-Path "$tempOutput") { Remove-Item "$tempOutput" -Force }
        }
    } catch {
        # Continuer
    }
    
    Start-Sleep -Seconds $interval
    $elapsed += $interval
}

Write-Host ""
Write-Host "⚠️ Temps d'attente depasse. Vous pouvez verifier le build et recuperer le fichier ici :" -ForegroundColor Yellow
Write-Host "https://github.com/$repo/releases" -ForegroundColor Cyan
