@echo off
echo.
echo =======================================================
echo   SARAH IA - COMPILATION AUTOMATIQUE IOS (IPA)
echo   Bundle ID : com.sarahia.app - Target : iPhone / iPad
echo =======================================================
echo.

echo [1/3] Synchronisation des fichiers et assets VRM iOS...
copy /Y "sarah_ai_web.html" "SarahIA\SarahIA\sarah_ai_web.html" >nul
copy /Y "vrm_data.js" "SarahIA\SarahIA\vrm_data.js" >nul
copy /Y "AA.vrm" "SarahIA\SarahIA\AA.vrm" >nul
copy /Y "AA.vrm" "SarahIA\SarahIA\Sarah.vrm" >nul
echo   [OK] Assets 3D VRM synchronises dans le Bundle Xcode iOS.
echo.

echo [2/3] Sauvegarde et declenchement du build sur GitHub...
git add -A
git commit -m "Build iOS IPA: Sarah IA com.sarahia.app avec Avatar 3D VRM" --allow-empty
git push origin main
echo   [OK] Build lance sur les serveurs macOS !
echo.

echo [3/3] Recuperation et telechargement automatique du fichier IPA...
powershell -ExecutionPolicy Bypass -File .\download_deliverable.ps1 -Type ipa

echo.
pause
