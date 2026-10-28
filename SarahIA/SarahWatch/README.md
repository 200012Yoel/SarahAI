# Sarah IA Watch · prototype 1

App compagnon watchOS dans le **même projet Xcode** et le **même dépôt** que Sarah IA pour iPhone.

## Première version
- Animation d'ouverture avec orbe lumineux bleu.
- QR code standard **réellement décodable** (Core Image) avec identifiant aléatoire propre à l'installation watchOS.
- Scanner natif sur iPhone (AVFoundation) via **Réglages → Apple Watch** ou la phrase « Connecter Apple Watch » dans le chat de Sarah.
- La montre valide le code reçu uniquement via Watch Connectivity depuis **son iPhone jumelé**; retour « Connectée » sur les deux écrans.
- Bouton « Traduction » sur Apple Watch envoyant une demande à l'iPhone pour ouvrir l'interface existante hébreu → français **quand l'app iOS est visible**.
- Si l'iPhone n'est pas au premier plan, la demande est mémorisée et traitée à la prochaine ouverture de Sarah (watchOS ne peut pas forcer l'affichage de l'application iPhone).

## Installation / tests
Ouvrir `SarahIA/SarahIA.xcodeproj` sur un Mac avec un Xcode intégrant le SDK watchOS.
La cible **SarahWatch** est intégrée à l'application **SarahIA**.
Pour une installation réelle, il faut une **signature valide** couvrant les deux identifiants `com.sarahia.app` et `com.sarahia.app.watchkitapp`, un iPhone et une Apple Watch compatibles.
Un workflow GitHub Actions séparé tente de compiler la cible watchOS dans le simulateur, sans signature.

## Limites explicites de cette V1
- **Le microphone de la montre n'est pas encore transmis vers l'iPhone.** La fonction « Traduction » déclenche le mode de traduction iPhone déjà présent; l'acquisition audio TV depuis la montre est une phase suivante et nécessitera des essais sur appareil réel.
- **Pas de lancement forcé de l'interface iOS** depuis watchOS : iOS décide des exécutions en arrière-plan. La V1 ne contourne pas cette règle.
- Le QR n'est **pas** le motif animé propriétaire de jumelage d'Apple. C'est un QR classique, stylisé dans l'interface, qui reste lisible par la caméra.
- Le QR n'est pas une identité en ligne. La connexion réelle entre appareils repose sur le jumelage officiel iOS/watchOS et WCSession.
- Le code est un premier prototype non testé sur montre réelle. Aucun IPA installé ni distribué.

## Essai
1. Installer la version compagnon sur l'iPhone et la montre via un build signé.
2. Ouvrir Sarah IA sur l'Apple Watch et afficher le QR code.
3. Sur l'iPhone, ouvrir Sarah IA → Réglages → Apple Watch → Scanner, ou saisir « Connecter Apple Watch » dans Sarah.
4. Scanner le QR de la montre, vérifier la confirmation « Connectée ».
5. Depuis la montre, toucher « Traduction », puis consulter Sarah sur l'iPhone.

**Évolutions**: capture micro watchOS en segments, streaming contrôlé et traduction vocale via l'iPhone, avec limites de batterie et latence documentées.
