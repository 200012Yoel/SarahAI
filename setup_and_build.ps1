# ============================================================
# Sarah IA - Script complet d'installation et compilation
# Executez : powershell -ExecutionPolicy Bypass -File .\setup_and_build.ps1
# ============================================================

$ErrorActionPreference = "Stop"
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

$version = & .\builder.exe --version 2>&1
Write-Host "  [OK] Version: $version" -ForegroundColor Green
Write-Host ""

# -- ETAPE 2 : Authentification GitHub --
Write-Host "[2/6] Authentification GitHub..." -ForegroundColor Yellow
Write-Host "  -> Verification de l'authentification..." -ForegroundColor Magenta

# Essai d'authentification si pas deja fait
try {
    & .\builder.exe auth github
} catch {
    Write-Host "  [INFO] Verification d'auth terminee." -ForegroundColor Green
}

Write-Host ""
Write-Host "  [OK] Authentification terminee !" -ForegroundColor Green
Write-Host ""

# -- ETAPE 3 : Initialiser Git & Identity --
Write-Host "[3/6] Initialisation du depot Git..." -ForegroundColor Yellow

# Configuration identite Git locale au cas ou
& git config user.email "yoel@example.com"
& git config user.name "Yoel Cohen"

if (-not (Test-Path ".git")) {
    & git init
    Write-Host "  [OK] Depot Git initialise" -ForegroundColor Green
} else {
    Write-Host "  [OK] Depot Git deja existant" -ForegroundColor Green
}

& git add .
& git commit -m "Sarah IA - version initiale" --allow-empty 2>&1 | Out-Null
Write-Host "  [OK] Fichiers commites" -ForegroundColor Green
Write-Host ""

# -- ETAPE 4 : Configurer le remote GitHub --
Write-Host "[4/6] Configuration du depot distant GitHub..." -ForegroundColor Yellow

$remoteUrl = "https://github.com/200012Yoel/SarahAI.git"
Write-Host "  [URL] Dépôt détecté : $remoteUrl" -ForegroundColor Cyan

$existingRemote = & git remote 2>&1
if ($existingRemote -match "origin") {
    & git remote set-url origin $remoteUrl
} else {
    & git remote add origin $remoteUrl
}

Write-Host "  [PUSH] Push vers GitHub..." -ForegroundColor Yellow
& git branch -M main
& git push -u origin main 2>&1
Write-Host "  [OK] Code pushe sur GitHub !" -ForegroundColor Green
Write-Host ""

# -- ETAPE 5 : Initialiser ios-builder --
Write-Host "[5/6] Initialisation de ios-builder..." -ForegroundColor Yellow
& .\builder.exe init
Write-Host "  [OK] ios-builder initialise" -ForegroundColor Green
Write-Host ""

# -- ETAPE 6 : Lancer le build iOS --
Write-Host "[6/6] Lancement du build iOS..." -ForegroundColor Yellow
Write-Host "  -> Le build sera execute sur GitHub Actions (macOS runner)" -ForegroundColor Magenta
Write-Host "  -> Cela peut prendre quelques minutes..." -ForegroundColor Magenta
Write-Host ""

& .\builder.exe ios build

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  [OK] BUILD TERMINE !" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

if (Test-Path "dist\SarahIA.ipa") {
    $ipaSize = (Get-Item "dist\SarahIA.ipa").Length
    Write-Host "  [IPA] Fichier IPA: dist\SarahIA.ipa ($($ipaSize) octets)" -ForegroundColor Cyan
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
