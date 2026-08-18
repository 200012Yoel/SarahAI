@echo off
echo.
echo =======================================================
echo   SARAH IA - COMPILATION AUTOMATIQUE ANDROID (APK)
echo   Package : com.sarahia.app - Version : 1.0
echo =======================================================
echo.

echo [1/3] Synchronisation des fichiers et assets VRM Android...
if not exist "android\app\src\main\assets" mkdir "android\app\src\main\assets"
copy /Y "sarah_ai_web.html" "android\app\src\main\assets\sarah_ai_web.html" >nul
copy /Y "vrm_data.js" "android\app\src\main\assets\vrm_data.js" >nul
copy /Y "AA.vrm" "android\app\src\main\assets\AA.vrm" >nul
copy /Y "AA.vrm" "android\app\src\main\assets\Sarah.vrm" >nul
echo   [OK] Assets 3D VRM synchronises dans le projet Android.
echo.

echo [2/3] Sauvegarde et declenchement du build sur GitHub...
git add -A
git commit -m "Build Android APK: Sarah IA com.sarahia.app avec Avatar 3D VRM" --allow-empty
git push origin main
echo   [OK] Build lance sur les serveurs !
echo.

echo [3/3] Recuperation et telechargement automatique du fichier APK...
powershell -ExecutionPolicy Bypass -File .\download_deliverable.ps1 -Type apk

echo.
pause
