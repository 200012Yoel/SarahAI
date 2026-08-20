@echo off
echo.
echo =======================================================
echo   SARAH IA - COMPILATION IOS 12.0+ (IPHONE 5S / 6 / 6+)
echo   Target : iOS 12.0 a iOS 18.0 - Mode : UIKit Natif Fallback
echo =======================================================
echo.

echo [1/2] Sauvegarde et declenchement du build iOS 12 sur GitHub...
git add -A
git commit -m "Build iOS 12 Legacy: Sarah IA com.sarahia.app (Target: iOS 12.0)" --allow-empty
git push origin main
echo   [OK] Build iOS 12 lance sur les serveurs macOS !
echo.

echo [2/2] Recuperation et telechargement automatique de SarahIA-Legacy-iOS12.ipa...
powershell -ExecutionPolicy Bypass -File .\download_deliverable.ps1 -Type ipa-legacy

echo.
pause
