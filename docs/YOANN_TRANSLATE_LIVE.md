# Yoann · Translate Live multilingue (ordinateur → micro iPhone → traduction)

## Utilisation

- Lance une chaîne ou une vidéo sur **ton ordinateur**, puis place l'iPhone près des haut-parleurs.
- Ouvre **Sarah IA → Outils → Yoann · Translate Live** ou dis/écris **« Active Translate Live hébreu-français »**, **« Lance Translate Live espagnol-anglais »**, etc.
- Choisis la **langue entendue** (dont **détection automatique**) et la **langue de traduction**. Une recherche facilite le choix.
- Le microphone **de l'iPhone** capte le son de l'ordinateur externe. L'application n'intercepte pas le son interne d'une autre app sur l'iPhone.
- Après un segment de parole et environ 0,92 s de silence, Whisper le traite. Ensuite Yoann traduit, prononce (si la langue est vocalisable), puis réactive le microphone après la fin de la lecture et une courte temporisation anti-écho.
- Le microphone **reste fermé tant que Yoann parle**. Les appels/agents ne peuvent pas intercepter les transcriptions de ce mode.

## Étendue des langues, honnêtement

| Fonction | Moteur | Disponibilité |
| --- | --- | --- |
| Reconnaissance du son du PC | **Vrai OpenAI Whisper Base multilingue** via whisper.cpp | Catalogue de ~100 codes langues fournis par le tokenizer Whisper ; qualité inégale selon accent et langue |
| Reconnaissance automatique | Whisper | Oui, sur l'entrée microphone |
| **Traduction vocale vers l'anglais** | Whisper `translate=true` | Locale sur l'iPhone pour des langues d'entrée multilingues (la transcription originale n'est pas conservée dans cette voie rapide) |
| Traduction vers le français, l'hébreu, l'espagnol, etc. | Petit dictionnaire de phrases **exactes** ou **serveur LibreTranslate / Argos personnel** | **Pas garantie sans serveur** : le dictionnaire local ne couvre que quelques expressions FR/EN/HE |
| Sortie **parlée** | Supertonic 3 via sherpa-onnx, voix propre à Yoann (M3) | **31 langues**, dont FR, EN, ES, DE, AR, JA, etc. (sans hébreu) |
| Autres langues de sortie, dont hébreu | Affichage texte seulement | Une traduction réelle doit d'abord avoir été produite par le backend |

On peut choisir une grande variété de langues, mais cela **ne signifie pas qu'un vrai modèle de traduction vers toutes ces langues est installé sur l'iPhone**. Une langue de sortie sans voix neuronale indique clairement **« Texte »**. Une langue non installée sur le serveur entraîne une erreur visible, pas une fausse traduction.

## Traduction vers une autre langue que l'anglais, sans abonnement

Tu peux installer **LibreTranslate + Argos Translate** sur ton propre PC/serveur et importer les packs de langues disponibles et autorisés pour une activité commerciale. Ensuite, dans Translate Live, indique l'adresse de ce serveur dans **« Serveur de traduction open source »**.

- Pas de serveur public de traduction imposé par l'application ; aucune clé payante nécessaire si ton serveur est auto-hébergé.
- L'application n'envoie que le **texte transcrit** à l'URL configurée par l'utilisateur, **pas le son du microphone**.
- HTTPS fonctionne avec un serveur distant ; HTTP n'est accepté que sur réseau local privé (l'app a `NSAllowsLocalNetworking`). Ne configure pas un serveur en HTTP public.
- Le backend doit disposer du **modèle correspondant à la paire de langues** ; le choix affiché côté iPhone n'installe pas magiquement ce modèle.
- Si aucun serveur n'est configuré, la plupart des longues phrases vers FR/HE/ES échoueront avec un message explicite. **Il ne faut pas vendre cette version comme traducteur universel autonome.**

### Droits de revente et licences

**LibreTranslate** est sous **AGPL-3.0**, ce qui impose des obligations de licence et d'accès au code du serveur si tu le modifies et l'exploites sur un réseau. **Argos Translate** et **chacun de ses modèles linguistiques** ont des conditions de distribution et d'attribution à vérifier séparément. Le modèle de voix **Supertonic 3** est sous **OpenRAIL-M** et son runtime sherpa-onnx sous **Apache-2.0**. Voir [VOICE_LICENSES.md](VOICE_LICENSES.md). Un usage commercial n'implique pas une licence sans conditions.

Documentation des API du serveur : https://docs.libretranslate.com/guides/api_usage/

## Limites techniques

- Le fonctionnement est **par phrases, pas de la traduction simultanée sans aucune coupure**. Pendant que Yoann parle, le PC continue de diffuser : l'iPhone peut manquer une partie des paroles suivantes.
- Le temps du traitement dépend du modèle Whisper, du serveur de traduction choisi (s'il est utilisé), de la vitesse de synthèse et de la puissance de l'iPhone.
- Les changements de langue redémarrent la session proprement ; quitter l'écran ou passer en arrière-plan arrête le micro.
- La précision d'une traduction d'actualité, médicale, juridique ou autre sujet sensible doit être vérifiée indépendamment.

## Vérifications effectuées / restantes

- Les vérifications automatiques comprennent l'analyse syntaxique Swift, les références du projet Xcode, la présence de l'anti-écho et des tests ciblés sur les commandes multilingues.
- Il faut **faire tourner l'IPA sur un vrai iPhone** et tester les 31 langues de sortie, les packs de traduction du serveur, la latence, le Bluetooth, le micro et les interruptions avant de la commercialiser.
