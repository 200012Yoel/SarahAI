# Sarah IA

Canonical repository for **Sarah IA** — a native iOS (SwiftUI) assistant with a SceneKit / VRM 3D avatar, WidgetKit Home Screen widgets, on-device speech, and an Android counterpart.

**Active repo:** [github.com/200012Yoel/SarahAI](https://github.com/200012Yoel/SarahAI)  
The older GitHub repo `200012Yoel/Sarah` is empty (no commits) and is not used.

---

## What’s in this repo

| Area | Location | Notes |
|------|----------|--------|
| iOS app | `SarahIA/` | SwiftUI, SceneKit avatar (`AvatarEngine`, `VRMLoader`), TTS / mic |
| WidgetKit extension | `SarahIA/SarahIAWidgets/` | 8 widgets, App Group `group.com.sarahia.app` |
| VRM avatar | `SarahIA/SarahIA/Sarah.vrm` | Bundled 3D model (also `vrm_data.js` fallback) |
| Android app | `android/` | Kotlin client + home-screen widget |
| CI (IPA / APK) | `.github/workflows/` | `ios-build.yml`, `android-build.yml` |

Bundle IDs: app `com.sarahia.app`, widgets `com.sarahia.app.SarahIAWidgets`.

---

## iOS

Open `SarahIA/SarahIA.xcworkspace` (or `SarahIA.xcodeproj`) in Xcode. Scheme: **SarahIA**. Deployment target: **iOS 15**.

From Windows, `ipa.bat` triggers the GitHub Actions iOS build. The unsigned IPA can be installed with Sideloadly, AltStore, or TrollStore.

---

## Android

Open the `android/` Gradle project, or run `apk.bat`.

---

## Licence

Projet personnel — Tous droits réservés.
