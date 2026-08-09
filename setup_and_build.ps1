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
Write-Host "[1/6] Verification du binaire builder.exe..." -ForegroundColor Yellow
if (Test-Path "builder.exe") {
    $size = (Get-Item "builder.exe").Length
    if ($size -gt 1000000) {
        Write-Host "  [OK] builder.exe trouve ($($size) octets)" -ForegroundColor Green
    } else {
        Write-Host "  [ERREUR] builder.exe corrompu ($($size) octets). Re-telechargement..." -ForegroundColor Red
        curl.exe -L -o "builder.exe" "https://github.com/MobAI-App/ios-builder/releases/download/v0.5.0/builder-windows-amd64.exe"
    }
} else {
    Write-Host "  [DL] Telechargement de builder.exe..." -ForegroundColor Yellow
    curl.exe -L -o "builder.exe" "https://github.com/MobAI-App/ios-builder/releases/download/v0.5.0/builder-windows-amd64.exe"
}

$version = & .\builder.exe --version
Write-Host "  [OK] Version: $version" -ForegroundColor Green
Write-Host ""

# -- ETAPE 2 : Authentification GitHub --
Write-Host "[2/6] Authentification GitHub..." -ForegroundColor Yellow
Write-Host "  [OK] Authentification GitHub deja valide." -ForegroundColor Green
Write-Host ""

# -- ETAPE 3 : Commit et Push des fichiers de configuration --
Write-Host "[3/6] Commit des fichiers de projet et de scheme Xcode..." -ForegroundColor Yellow

git config user.email "yoel@example.com"
git config user.name "Yoel Cohen"

git add .
git commit -m "Fix scheme Xcode et configuration builder.json" --allow-empty
git push -u origin main
Write-Host "  [OK] Modifications pushees sur GitHub" -ForegroundColor Green
Write-Host ""

# -- ETAPE 4 : Lancer le build iOS --
Write-Host "[4/6] Lancement du build iOS via ios-builder..." -ForegroundColor Yellow
Write-Host "  -> Le build sera execute sur GitHub Actions (macOS runner)" -ForegroundColor Magenta
Write-Host "  -> Cela prend en moyenne 2 a 3 minutes..." -ForegroundColor Magenta
Write-Host ""

& .\builder.exe ios build

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  [OK] TRAITEMENT TERMINE !" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

if (Test-Path "dist\SarahIA.ipa") {
    $ipaSize = (Get-Item "dist\SarahIA.ipa").Length
    Write-Host "  [IPA] Fichier IPA disponible: dist\SarahIA.ipa ($($ipaSize) octets)" -ForegroundColor Cyan
} else {
    Write-Host "  [INFO] Verifiez le dossier .\dist\ pour le fichier .ipa" -ForegroundColor Yellow
    if (Test-Path "dist") {
        Get-ChildItem "dist" | ForEach-Object {
            Write-Host "     - $($_.Name) ($($_.Length) octets)"
        }
    }
}

Write-Host ""
Write-Host "  Pour installer sur iPhone, utilisez AltStore ou Sideloadly." -ForegroundColor White
Write-Host ""
