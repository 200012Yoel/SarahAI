# 🤖 Sarah IA — Assistant IA pour iPhone

Application iOS native (SwiftUI) d'assistant IA avec notifications en arrière-plan.  
Compatible **iPhone 8 (iOS 15)** → **iPhone 14+ (iOS 17+)**.

---

## 📁 Structure du projet

```
SarahIA/
├── SarahIA.xcodeproj/          ← Projet Xcode
├── SarahIA.xcworkspace/        ← Workspace Xcode
└── SarahIA/                    ← Code source
    ├── SarahIAApp.swift         ← Point d'entrée
    ├── ContentView.swift        ← Interface de chat
    ├── Models/Message.swift     ← Modèle de données
    ├── Services/
    │   ├── AIService.swift      ← IA simulée (réponses en français)
    │   └── NotificationService.swift ← Notifications locales
    ├── Views/
    │   ├── ChatBubbleView.swift      ← Bulles de message
    │   ├── MessageInputView.swift    ← Barre de saisie
    │   └── TypingIndicatorView.swift ← Animation "en train d'écrire"
    ├── ViewModels/
    │   └── ChatViewModel.swift  ← Logique de conversation
    ├── Assets.xcassets/         ← Couleurs et icônes
    └── Info.plist               ← Configuration iOS
```

---

## 🚀 Compilation en 4 étapes (Windows / sans Xcode)

### Prérequis
- [Node.js](https://nodejs.org/) (v18+)
- [Git](https://git-scm.com/)
- Un compte [GitHub](https://github.com/)

### Étape 1 — Installer `ios-builder`
```powershell
npm install -g ios-builder
```

### Étape 2 — Authentifier GitHub
```powershell
builder auth github
```
> Un navigateur s'ouvrira pour vous connecter à GitHub et autoriser `ios-builder`.

### Étape 3 — Initialiser le projet et push vers GitHub
```powershell
cd "c:\Users\Yoel Cohen\Downloads\Ikea iPhone"
git init
git add .
git commit -m "Sarah IA — version initiale"

# Créer un repo sur github.com, puis :
git remote add origin https://github.com/VOTRE_UTILISATEUR/sarah-ia.git
git push -u origin main

# Initialiser ios-builder
builder init
```

### Étape 4 — Compiler le .ipa
```powershell
builder ios build
```
> Le build sera lancé via GitHub Actions. Le fichier `.ipa` sera téléchargé automatiquement dans `./dist/SarahIA.ipa`.

---

## 📲 Installation sur iPhone

L'IPA générée est **non signée**. Pour l'installer :

| Méthode | Outil | Lien |
|---------|-------|------|
| Sideloading | **AltStore** | [altstore.io](https://altstore.io/) |
| Sideloading | **Sideloadly** | [sideloadly.io](https://sideloadly.io/) |
| Jailbreak | **TrollStore** | [github.com/opa334/TrollStore](https://github.com/opa334/TrollStore) |

---

## 🎯 Fonctionnalités

- 💬 **Chat interactif** avec réponses contextuelles en français
- 🤖 **IA simulée** avec détection de mots-clés (salutations, blagues, météo, etc.)
- 🔔 **Notifications en arrière-plan** — recevez la réponse même si l'app est minimisée
- 📱 **Compatible tous iPhones** — du 4.7" (iPhone 8) au 6.7" (iPhone 14 Plus/Pro Max)
- 🎨 **Design premium** avec dégradés, glassmorphism et animations

---

## 📝 Licence

Projet personnel — Tous droits réservés.
