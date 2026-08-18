@echo off
chcp 65001 >nul
cls
echo =======================================================
echo   🌟 SARAH IA — COMPILATEUR UNIVERSEL IOS & ANDROID
echo =======================================================
echo.
echo Choisissez ce que vous souhaitez compiler :
echo.
echo   [1] Compiler pour ANDROID (.apk)
echo   [2] Compiler pour IPHONE (.ipa)
echo   [3] Compiler les DEUX EN MEME TEMPS (.apk + .ipa)
echo   [0] Quitter
echo.
set /p choix="Votre choix (1, 2, 3 ou 0) : "

if "%choix%"=="1" (
    call apk.bat
    goto fin
)
if "%choix%"=="2" (
    call ipa.bat
    goto fin
)
if "%choix%"=="3" (
    echo.
    echo =======================================================
    echo   🚀 COMPILATION DES DEUX APPLICATIONS EN PARALLELE
    echo =======================================================
    echo.
    git add -A
    git commit -m "Build All: Sarah IA com.sarahia.app (Android APK + iOS IPA)" --allow-empty
    git push origin main
    echo.
    echo [OK] Push effectue ! Les 2 builds GitHub (iOS + Android) tournent simultanement.
    echo.
    echo 👉 Suivre vos builds : https://github.com/200012Yoel/SarahAI/actions
    echo 👉 Telechargements : https://github.com/200012Yoel/SarahAI/releases
    echo.
    pause
    goto fin
)
if "%choix%"=="0" (
    goto fin
)

:fin
