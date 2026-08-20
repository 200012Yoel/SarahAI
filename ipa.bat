@echo off
echo.
echo =======================================================
echo   SARAH IA - COMPILATION AUTOMATIQUE IOS (IPA)
echo   Bundle ID : com.sarahia.app - Target : iPhone / iPad
echo =======================================================
echo.

echo [1/2] Sauvegarde et declenchement du build sur GitHub...
git add -A
git commit -m "Build iOS IPA: Sarah IA com.sarahia.app" --allow-empty
git pull --rebase origin main
git push origin main
echo   [OK] Build lance sur les serveurs macOS !
echo.

echo [2/2] Recuperation et telechargement automatique du fichier IPA...
powershell -ExecutionPolicy Bypass -File .\download_deliverable.ps1 -Type ipa

echo.
pause
