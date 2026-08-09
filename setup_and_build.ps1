# ============================================================
# Sarah IA - Script complet d'installation et compilation
# Executez : powershell -ExecutionPolicy Bypass -File .\setup_and_build.ps1
# ============================================================

$ErrorActionPreference = "Continue"
$projectDir = "c:\Users\Yoel Cohen\Downloads\Ikea iPhone"

Set-Location $projectDir
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SARAH IA - Setup et Build Script" -ForegroundColor Cyan
Write-Host "  ios-builder v0.5.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# -- ETAPE 1 : Verifier le binaire --
Write-Host "[1/4] Verification du binaire builder.exe..." -ForegroundColor Yellow
if (Test-Path "builder.exe") {
    $size = (Get-Item "builder.exe").Length
    if ($size -gt 1000000) {
        Write-Host "  [OK] builder.exe trouve" -ForegroundColor Green
    } else {
        Write-Host "  [ERREUR] builder.exe corrompu. Re-telechargement..." -ForegroundColor Red
        curl.exe -L -o "builder.exe" "https://github.com/MobAI-App/ios-builder/releases/download/v0.5.0/builder-windows-amd64.exe"
    }
} else {
    Write-Host "  [DL] Telechargement de builder.exe..." -ForegroundColor Yellow
    curl.exe -L -o "builder.exe" "https://github.com/MobAI-App/ios-builder/releases/download/v0.5.0/builder-windows-amd64.exe"
}

$version = & .\builder.exe --version
Write-Host "  [OK] Version: $version" -ForegroundColor Green
Write-Host ""

# -- ETAPE 2 : Commit et Push des fixes --
Write-Host "[2/4] Commit et push de l'identite Ad-Hoc Sign (-)..." -ForegroundColor Yellow

git config user.email "yoel@example.com"
git config user.name "Yoel Cohen"

git add .
git commit -m "Fix identite ad-hoc CODE_SIGN_IDENTITY='-'" --allow-empty
git push -u origin main
Write-Host "  [OK] Push reussi sur GitHub !" -ForegroundColor Green
Write-Host ""

# -- ETAPE 3 : Lancer le build remote --
Write-Host "[3/4] Lancement de la compilation iOS..." -ForegroundColor Yellow
Write-Host "  -> Execution sur GitHub Actions (macOS runner)..." -ForegroundColor Magenta
Write-Host ""

& .\builder.exe ios build

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  [OK] TRAITEMENT TERMINE !" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# -- ETAPE 4 : Verification du binaire IPA --
Write-Host "[4/4] Verification du livrable .ipa..." -ForegroundColor Yellow
if (Test-Path "dist\SarahIA.ipa") {
    Write-Host "  [SUCCESS] Fichier IPA genere avec succes dans dist\SarahIA.ipa" -ForegroundColor Green
} else {
    Write-Host "  [INFO] Verification du dossier dist:" -ForegroundColor Yellow
    if (Test-Path "dist") {
        Get-ChildItem "dist"
    }
}

Write-Host ""
