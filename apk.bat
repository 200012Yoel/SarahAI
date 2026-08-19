@echo off
echo.
echo =======================================================
echo   SARAH IA - COMPILATION AUTOMATIQUE ANDROID (APK)
echo   Package : com.sarahia.app - Version : 1.1
echo =======================================================
echo.

echo [1/2] Sauvegarde et declenchement du build sur GitHub...
git add -A
git commit -m "Build Android APK: Sarah IA com.sarahia.app v1.1" --allow-empty
git push origin main
echo   [OK] Build lance sur les serveurs !
echo.

echo [2/2] Recuperation et telechargement automatique du fichier APK...
powershell -ExecutionPolicy Bypass -File .\download_deliverable.ps1 -Type apk

echo.
pause
