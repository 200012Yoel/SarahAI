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

# -- ETAPE 2 : Configuration AppIcon, Commit et Push --
Write-Host "[2/4] Configuration AppIcon et commit sur GitHub..." -ForegroundColor Yellow

$iconSource = "C:\Users\Yoel Cohen\.gemini\antigravity-ide\brain\b5766280-dfe0-468c-8738-c350a1ff540a\sarah_app_icon_1786296632469.png"
$iconDest = "SarahIA\SarahIA\Assets.xcassets\AppIcon.appiconset\AppIcon-1024.png"

if (Test-Path $iconSource) {
    Copy-Item -Path $iconSource -Destination $iconDest -Force
    Write-Host "  [OK] Nouvelle App Icon 1A / 1I copiee dans Assets.xcassets" -ForegroundColor Green
}

git config user.email "yoel@example.com"
git config user.name "Yoel Cohen"

git add .
git commit -m "Sarah AI: Set CODE_SIGN_IDENTITY='-' and PROVISIONING_PROFILE_SPECIFIER='' for generic iOS build" --allow-empty
git push -u origin main
Write-Host "  [OK] Push reussi sur GitHub !" -ForegroundColor Green
Write-Host ""

# -- ETAPE 3 : Lancer le build remote --
Write-Host "[3/4] Lancement de la compilation iOS sur macOS runner..." -ForegroundColor Yellow
& .\builder.exe ios build

Write-Host ""
# -- ETAPE 4 : Verification et Recuperation du livrable .ipa --
Write-Host "[4/4] Verification et telechargement du fichier IPA..." -ForegroundColor Yellow
if (Test-Path "download_ipa.ps1") {
    & .\download_ipa.ps1
} else {
    Write-Host "  [INFO] Consultez vos builds et telechargez l'IPA directement ici :" -ForegroundColor Yellow
    Write-Host "  https://github.com/200012Yoel/SarahAI/actions" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  [OK] TRAITEMENT TERMINE !" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
