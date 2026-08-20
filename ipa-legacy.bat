@echo off
echo.
echo ==================================================================
echo   📱 SARAH IA - COMPILATION IPHONE 5S / IPHONE 6 (iOS 12.0+)
echo   Target : iPhone 5S, 6, 6 Plus (iOS 12.5.8) - Mode UIKit Natif
echo ==================================================================
echo.

echo [1/2] Sauvegarde et declenchement du build iPhone 5S sur GitHub...
git add -A
git commit -m "Build iPhone 5S (iOS 12.0+): com.sarahia.app" --allow-empty
git push origin main
echo   [OK] Build iPhone 5S lance sur les serveurs macOS !
echo.

echo [2/2] Recuperation et telechargement automatique de SarahIA-iPhone5S-iOS12.ipa...
powershell -ExecutionPolicy Bypass -File .\download_deliverable.ps1 -Type ipa-legacy

echo.
pause
