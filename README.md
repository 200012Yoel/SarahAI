# 👑 Sarah IA — Moteur IA Local Adaptatif Multi-Générations iOS

Sarah IA est une application d'assistance intelligente autonome pour iPhone (compatible iOS 12.0+ jusqu'à iOS 18.0+), conçue pour fonctionner **100% en local et hors-ligne**.

Elle intègre une **architecture adaptative multi-matérielle** qui ajuste en temps réel la puissance du modèle, la gestion de la mémoire et la cadence de génération selon la génération exacte de l'iPhone.

---

## 🏛️ Architecture Globale du Moteur IA Adaptatif

```text
                               ┌────────────────────────┐
                               │   IPA Bundle (.app)    │
                               │ (Lecture Seule - Intact)│
                               └───────────┬────────────┘
                                           │
                                           ▼
┌───────────────────────────────────────────────────────────────────────────────────┐
│                           DeviceCapabilityDetector                                │
│       • RAM Physique (ProcessInfo)            • RAM Disponible (os_proc_avail)    │
│       • Cœurs CPU Actifs                      • Puce Apple (A7 -> A19 Pro)        │
│       • État Thermique (ProcessInfo)          • Budget Mémoire Sécurisé           │
└──────────────────────────────────────────┬────────────────────────────────────────┘
                                           │
                                           ▼
┌───────────────────────────────────────────────────────────────────────────────────┐
│                             ModelSelectionEngine                                  │
│  Tier 1 : iPhone 5s/6/SE1  ➔ Modèle Nano (Ctx 512, ~80 Mo RAM)                    │
│  Tier 2 : iPhone 7/8       ➔ Modèle Micro (Ctx 1024, ~200 Mo RAM)                 │
│  Tier 3 : iPhone X/11      ➔ Modèle Core (Ctx 2048, ~400 Mo RAM)                  │
│  Tier 4 : iPhone 12/13     ➔ Modèle Pro (Ctx 3072, ~750 Mo RAM)                   │
│  Tier 5 : iPhone 14/14 Pro ➔ CIBLE PRINCIPALE Flagship (Ctx 4096, ~1.2 Go RAM)    │
│  Tier 6 & 7 : iPhone 15/16/17+ ➔ Profils Ultra & Max Titan (Ctx 6144 à 8192)      │
│  [Sécurité] Fallback automatique vers Tier inférieur en cas de pression mémoire  │
└──────────────────────────────────────────┬────────────────────────────────────────┘
                                           │
                                           ▼
┌───────────────────────────────────────────────────────────────────────────────────┐
│                             EmbeddedModelManager                                  │
│  1. Copie sécurisée du modèle validé vers : Application Support/ai_models/        │
│  2. Validation de structure et test d'intégrité minimal avant activation          │
│  3. Maintien obligatoire du modèle de secours (Fallback)                          │
│  4. Nettoyage progressif asynchrone hors MainActor des anciennes copies           │
└──────────────────────────────────────────┬────────────────────────────────────────┘
                                           │
                                           ▼
┌───────────────────────────────────────────────────────────────────────────────────┐
│                    AIResourceManager & AIProgressiveScheduler                     │
│  • Mode Ralenti Intelligent : NORMAL ➔ SLOWDOWN ➔ DEEP_SLOWDOWN ➔ CRITICAL        │
│  • Micro-pauses et désengorgement selon la température (thermalState)             │
│  • Buffer de streaming fluide à 60 FPS (AIStreamingBuffer)                        │
│  • Annulation instantanée et propre lors d'un Stop ou changement d'écran          │
└──────────────────────────────────────────┬────────────────────────────────────────┘
                                           │
                                           ▼
┌───────────────────────────────────────────────────────────────────────────────────┐
│                       👑 SARAH (Orchestratrice Centrale)                          │
│                    + Model Identity Privacy Layer (Confidentialité)                │
└──────────────┬───────────────────────────┼───────────────────────────┬────────────┘
               │                           │                           │
               ▼                           ▼                           ▼
        🌍 TOM (Histoire &        ⚡ RAPHAËL (Dev &           🇮🇱 YOHAN (Traduction &
           Géopolitique)             VAI Coding)                 Lexique FR ⇄ HE)
```

---

## 👥 Les 4 Agents Spécialisés

Sarah IA conserve une équipe de 4 agents aux personnalités et compétences distinctes. L'utilisateur s'adresse à Sarah par défaut, et la bascule s'effectue par simple commande vocale naturelle (*« Passe-moi Tom »*, *« Donne-moi Raphaël »*, *« Passe-moi Yohan »*) avec passation fluide (*« Attends, je te le passe ! »*).

| Agent | Rôle & Spécialité | Couleur & Thème | Fonctionnalités Clés |
|:---|:---|:---:|:---|
| 👑 **Sarah** | **Patronne & Agent Pilote** | Rose Néon / Couronne | Orchestration générale, recherche web, météo en direct, alertes Pikoud HaOref, flash/torche, batterie, vision locale et mémoire longue durée (Memory Vault). |
| 🌍 **Tom** | **Géopolitique & Histoire Contemporaine** | Bleu Stratégique | Analyse politique mondiale depuis 1948, conflits du Moyen-Orient, Ve République française, débats structurés et chronologies détaillées. |
| ⚡ **Raphaël** | **Expert Développeur & VAI Coding** | Vert Cyber / Matrix | Génération de composants Web (HTML/CSS/JS), code Swift / SwiftUI natif, Apple Shortcuts et intégration dans le studio interactif VAI Code Studio. |
| 🇮🇱 **Yohan** | **Lexique & Traduction Multilingue** | Or & Ambre | Traduction bidirectionnelle Français ⇄ Hébreu, phonétique, racines sémitiques, grammaire et expressions idiomatiques israéliennes. |

---

## ⚙️ Détails Techniques des Composants

### 1. `DeviceCapabilityDetector` & `DeviceCapabilityProfile`
* Détection dynamique des ressources matérielles sans aucune valeur codée en dur.
* Mesure la RAM physique totale (`ProcessInfo.processInfo.physicalMemory`), la mémoire disponible au processus (`os_proc_available_memory`), le nombre de processeurs actifs et la famille de puce Apple (Apple A7 jusqu'à A19 Pro et M-Series).
* Calcule un budget mémoire sécurisé avec une marge de réserve de 40% dédiée à l'OS et à l'interface graphique.

### 2. `ModelSelectionEngine` & `ModelProfile`
* Mappe les capacités détectées vers le profil le plus puissant stable :
  * **iPhone 14 / 14 Pro (Cible Principale)** : Profil Tier 5 haute performance, contexte 4096 tokens, streaming temps réel et accélération neuronale.
  * **iPhone 5s / 6 / SE 1** : Profil Tier 1 compact optimisé pour 1 Go de RAM (contexte 512).
  * **iPhone 7 / 8** : Profil Tier 2 adapté à l'A10/A11 (contexte 1024).
  * **iPhone 11 / 12 / 13** : Profils Tier 3 & Tier 4 équilibrés (contexte 2048 à 3072).
  * **iPhone 15 / 16 / 17+** : Profils Tier 6 & Tier 7 ultra-performants (contexte 6144 à 8192).
* **Fallback Automatique** : Si la mémoire disponible mesurée est inférieure au seuil requis, le moteur rétrograde immédiatement et sans crash vers le modèle immédiatement inférieur.

### 3. `EmbeddedModelManager` (Architecture de Stockage en Deux Étapes)
* **Respect du Sandbox iOS** : `Bundle.main` est strictement en lecture seule. Aucun fichier du bundle n'est altéré ou supprimé.
* **Déploiement sécurisé** : Les configurations sont copiées vers `Application Support/ai_models/` lors du premier démarrage ou des mises à jour.
* **Validation d'intégrité** : Le fichier copié est validé avant d'être activé. En cas d'anomalie, le modèle de secours (fallback) est maintenu.
* **Nettoyage Asynchrone** : Les anciennes copies devenues inutiles dans `Application Support` sont supprimées progressivement en tâche de fond (`utility`), sans jamais bloquer le `MainActor`.

### 4. `AIResourceManager` & `AIProgressiveScheduler` (Mode Ralenti Intelligent)
* Surveillance continue de la pression mémoire (`UIApplication.didReceiveMemoryWarningNotification`) et de la température (`ProcessInfo.thermalStateDidChangeNotification`).
* **Régulation adaptative des délais** :
  * `NORMAL` : 0 ms de délai supplémentaire.
  * `SLOWDOWN` : +15 ms de micro-pause entre les lots de tokens.
  * `DEEP_SLOWDOWN` : +40 ms d'espacement et réduction temporaire de la longueur de contexte.
  * `CRITICAL` : +90 ms, purge des caches transitoires et suspension des tâches d'arrière-plan tout en maintenant la réponse utilisateur prioritaire.
* **Streaming à 60 FPS** (`AIStreamingBuffer`) : Les tokens sont agrégés par micro-lots temporels (~35 ms) pour éviter de déclencher des rafraîchissements excessifs dans SwiftUI.
* **Annulation propre** (`cancelAllTasks()`) : Arrêt immédiat de la génération lors d'un tap sur Stop, d'un changement de conversation ou de la suppression d'un historique.

### 5. `Model Identity Privacy Layer`
* **Sarah reste Sarah** : Elle ne révèle jamais de noms de LLM sous-jacents, familles, architectures, nombre de paramètres ou types de quantification (Llama, Qwen, Mistral, ChatGPT, GGUF, etc.).
* En cas de question sur son moteur (*« Quel modèle utilises-tu ? »*), Sarah répond sobrement et avec élégance qu'elle est Sarah, l'assistante IA locale et autonome de l'application.
* Aucun détail technique n'apparaît dans l'interface utilisateur.

---

## 📱 Compatibilité & Installation

* **Binaire Universel** : `SarahIA.ipa` (~20.7 Mo)
* **Systèmes supportés** : iOS 12.0, iOS 13.0, iOS 14.0, iOS 15.0, iOS 16.0, iOS 17.0, iOS 18.0+
* **Appareils compatibles** : iPhone 5S, iPhone 6, iPhone 6 Plus, iPhone 6S, iPhone SE (1ère et 2ème gén), iPhone 7, iPhone 8, iPhone X/XR/XS, iPhone 11, iPhone 12, iPhone 13, **iPhone 14 / 14 Pro**, iPhone 15 / 15 Pro, iPhone 16.
* **Outils d'installation recommandés** : Sideloadly, AltStore, TrollStore.

---

## 🛠️ Compilation & Intégration Continue (CI/CD)

Le projet dispose d'un workflow GitHub Actions automatisé sur runners macOS (`.github/workflows/ios-build.yml`) :
1. Détection automatique du projet Xcode `SarahIA.xcodeproj`.
2. Compilation native Release Mach-O compatible iOS 12.0+ universel.
3. Signature ad-hoc et packaging de `SarahIA.ipa`.
4. Publication automatique sur GitHub Releases.
