# 👑 Sarah IA — Assistant multi-agents pour iOS

Sarah IA est une application iOS centrée sur **Sarah**, l’orchestratrice principale. Sarah route les demandes vers les agents et moteurs adaptés, tout en indiquant clairement ce qui s’exécute localement et ce qui nécessite un runtime réseau configuré.

## 👥 Les agents

| Agent | Rôle principal |
| --- | --- |
| 👑 **Sarah** | Orchestration générale, conversation et coordination des modèles |
| 💻 **Raphaël** | Développement web, SwiftUI, scripts, automatisations et atelier de code |
| 🌍 **Tom** | Recherche, histoire et explications documentées |
| 🇮🇱 **Yohan** | Traduction français ↔ hébreu |
| 🤖 **Nathan** | Réseaux sociaux et contenus |
| ✨ **Ethel** | Création et design |

## 🧠 Sarah Engine

Sarah pilote les familles de modèles de texte, code, vision, image, vidéo, musique, traduction et recherche. Les fonctions locales utilisent les capacités disponibles sur l’iPhone. Lorsqu’un moteur externe ou auto-hébergé est nécessaire, l’application doit l’indiquer au lieu de présenter le traitement comme local.

Le pipeline vocal s’appuie sur les frameworks audio Apple, la reconnaissance vocale et la synthèse `AVSpeechSynthesizer`. Les agents peuvent recevoir des profils vocaux Apple distincts selon les voix installées sur l’appareil.

## 💻 Raphaël · développement agentique

Le développement web utilise deux rôles complémentaires :

- **Qwen3-Coder-Next · Architecte** comprend la demande en langage naturel, le contexte du projet, les contraintes et prépare le plan de modification.
- **Qwen3-Coder-30B-A3B-Instruct · Code Worker** écrit, refactorise et corrige le code à partir du plan.

Ces modèles sont référencés sous licence Apache-2.0. Leurs gros poids ne sont pas embarqués dans l’IPA. Dans **Réglages > Sarah Engine**, un endpoint OpenAI-compatible auto-hébergé peut être configuré pour les utiliser. Sans endpoint disponible, Raphaël utilise le générateur local de secours et l’indique explicitement.

### Projet persistant et corrections successives

Raphaël conserve le projet web courant dans `Documents/VAI_Workspace/index.html` ainsi qu’un état de révision. Une consigne suivante telle que « corrige ce bouton », « change ce texte », « ajoute une section » ou « rends-le plus Apple » repart donc du projet existant plutôt que d’ouvrir un projet indépendant.

### Test intégré

Après la génération, Sarah effectue un audit HTML puis charge le résultat dans un `WKWebView` de test. Le contrôle vérifie notamment :

- le chargement du DOM ;
- les erreurs JavaScript interceptées ;
- le débordement horizontal sur une largeur mobile ;
- les images cassées ;
- la structure HTML et le viewport responsive.

Si le runtime de code est connecté et que le test échoue, le Code Worker peut recevoir le rapport d’erreur, corriger le document et le faire tester une seconde fois.

## 🎙️ Dictée et lecture

La dictée de la barre de saisie possède un état dédié avec niveau micro réel, arrêt vers le champ de saisie et envoi explicite. Les réponses de l’assistant disposent également d’une action de lecture à voix haute.

## 🌐 Rendu web

L’interface utilise un seul rendu web responsive adapté à la largeur du téléphone. L’ancien choix entre plusieurs simulateurs visuels n’est plus utilisé.

## 🔒 Principe de transparence

Sarah ne doit pas annoncer qu’un moteur lourd fonctionne directement sur l’iPhone si ce runtime n’est pas réellement présent. Les modèles externes restent optionnels et le comportement de secours local reste disponible quand ils ne sont pas configurés.
