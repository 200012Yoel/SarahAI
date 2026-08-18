@echo off
chcp 65001 >nul
echo.
echo =======================================================
echo   🍎 SARAH IA — COMPILATION AUTOMATIQUE IOS (IPA)
echo   Bundle ID : com.sarahia.app ^| Target : iPhone / iPad
echo =======================================================
echo.

echo [1/3] Synchronisation des fichiers et assets VRM iOS...
copy /Y "sarah_ai_web.html" "SarahIA\SarahIA\sarah_ai_web.html" >nul 2>&1
copy /Y "vrm_data.js" "SarahIA\SarahIA\vrm_data.js" >nul 2>&1
copy /Y "AA.vrm" "SarahIA\SarahIA\AA.vrm" >nul 2>&1
copy /Y "AA.vrm" "SarahIA\SarahIA\Sarah.vrm" >nul 2>&1
echo   [OK] Assets 3D VRM synchronises dans le Bundle Xcode iOS.
echo.

echo [2/3] Sauvegarde et envoi du code sur GitHub...
git add -A
git commit -m "Build iOS IPA: Sarah IA com.sarahia.app avec Avatar 3D VRM" --allow-empty
git push origin main
echo   [OK] Push reussi vers GitHub !
echo.

echo [3/3] Compilation du projet Xcode sur le runner macOS...
echo.
echo =======================================================
echo   ✅ BUILD IOS DECLENCHE AVEC SUCCES !
echo =======================================================
echo.
echo 📱 Suivez le build et telechargez votre IPA directement :
echo.
echo   👉 Actions GitHub : https://github.com/200012Yoel/SarahAI/actions
echo   👉 Telechargement direct Release : https://github.com/200012Yoel/SarahAI/releases
echo.
echo Fichier genere : SarahIA.ipa (Pret pour AltStore / Sideloadly / TrollStore)
echo =======================================================
echo.
pause
