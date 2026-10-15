# Yoann · Translate Live : interprète continu (micro iPhone → écouteurs)

## Le scénario réellement pris en charge

Une **personne en hébreu**, ou une télévision/vidéo **sur l'ordinateur à côté de l'iPhone**, parle. L'iPhone capte l'audio extérieur avec **son microphone**, analyse de courts segments avec **OpenAI Whisper** et tente de prononcer leur traduction dans les **écouteurs**. Aucune capture du son interne d'une autre app iOS n'est requise.

- Ouvre **Sarah → Outils → Yoann · Translate Live** et choisis les langues (y compris entrée automatique).
- Pose l'iPhone près de la personne ou des haut-parleurs du PC ; garde de préférence des écouteurs branchés pour entendre Yoann sans faire rejouer sa voix par les haut-parleurs de l'iPhone.
- Le flux micro est **continu**, sans pause programmée entre les phrases. Whisper découpe la parole après une courte pause (~0,28 seconde) ou environ **2,1 secondes maximum** de parole soutenue, avec un minimum de ~0,5 seconde de son.
- Les transcriptions peuvent être traduites pendant que la capture continue ; la voix synthétique peut jouer pendant que le micro est encore actif. L'interface affiche les segments et les erreurs.
- **Texte provisoire et texte confirmé** : les hypothèses de Whisper sont conservées brièvement au lieu de tout prononcer aussitôt. Une micro-pause stabilise immédiatement un passage court ; une hypothèse prolongée peut réviser le texte provisoire avant émission. Seuls les segments confirmés sont traduits et envoyés dans l'écouteur. Les nouveaux mots apparaissent après le décodage d'un segment, **pas lettre par lettre ni mot par mot garanti**.
- **Mémoire contextuelle courte** : les six derniers segments confirmés (jusqu'à environ 400 caractères) sont conservés ; un extrait maximal de 220 caractères sert de prompt initial au décodeur Whisper suivant. Cela aide la cohérence de reconnaissance du sujet mais **ne rend pas Marian context-aware** : accords de genre, pronoms et reconstruction grammaticale en français ne sont pas garantis.
- **Variétés d'anglais** : Anglais (Royaume-Uni) et Anglais (États-Unis) sont deux options de l'interface et des commandes vocales, normalisées en `en` pour Whisper, le moteur de traduction et Supertonic 3. Le modèle reconnaît des accents variés mais **ne produit pas deux voix régionales garanties**. Il faudra évaluer une vraie synthèse UK/US avant de vendre cette fonctionnalité comme deux accents distincts.
- **Arrêter** ou fermer l'interface met fin à la capture. Aucune minuterie de session ni quota de traduction n'a été codé. La durée pratique dépend de la batterie, du CPU, de la mémoire et des règles audio iOS.
- Lorsque l'écran se verrouille ou que l'app passe en arrière-plan, nous ne forçons plus l'arrêt ; toutefois iOS peut interrompre/suspendre l'audio, ce qui **nécessite un essai sur iPhone**.

## Performances réelles : ne pas prétendre « latence zéro »

La chaîne comporte trois étapes non nulles : (1) collecter assez de parole pour comprendre ; (2) Whisper et le modèle de traduction ; (3) synthèse Supertonic et sortie audio. Le TTS Yoann utilise **5 étapes de diffusion** au lieu de 8 pour commencer à produire le son plus rapidement, avec une qualité potentiellement moindre.

Le micro tourne sur son propre flux **pendant l'inférence** ; les segments et les lectures sont placés dans des files d'attente bornées pour ne pas faire exploser la mémoire. Si le processeur ou le serveur est trop lent, le service affiche un avertissement et peut ignorer un segment ancien. Il est donc **illimité en durée demandée, pas garanti sans aucun retard ni aucune perte**. Les performances ne sont pas encore mesurées sur l'iPhone.

### Paires linguistiques

| Sens | Traduction | Voix |
| --- | --- | --- |
| Langue Whisper → anglais | **Whisper `translate=true` local** ; sans serveur | Anglais Supertonic 3 |
| Hébreu → français | Quelques expressions exactes embarquées ; sinon **vrai modèle Helsinki-NLP/opus-mt-he-fr sur serveur local Docker**, si installé et configuré | Français Supertonic 3 |
| Autres langues → français et autres directions | Dictionnaire minuscule ou serveur compatible API LibreTranslate avec les modèles correspondants | Supertonic 3 si la destination fait partie de ses 31 langues ; texte seul sinon |

**Important :** le modèle hébreu → français **n'est pas installé dans l'IPA de l'iPhone**. Sans serveur accessible sur le réseau local, Sarah ne sait pas traduire une vraie conversation hébraïque complète en français. Il n'existe donc pas encore de traducteur universel local iPhone prêt à commercialiser.

Serveur réel HE→FR : voir [server/translate-live/README.md](../server/translate-live/README.md). Modèle [Helsinki-NLP/opus-mt-he-fr](https://huggingface.co/Helsinki-NLP/opus-mt-he-fr) annoncé Apache-2.0. Ce modèle effectue les traductions sur CPU, sans quota ni API payante ; il nécessite une connexion pour le télécharger la première fois et de la RAM/CPU pendant l'usage.

L'iPhone n'envoie **que le texte transcrit** au serveur défini dans l'écran ; **pas la voix brute**. Si tu le configures en HTTP sur ton Wi-Fi, les textes ne sont pas chiffrés sur le réseau. Ne rends pas le port public ; protège le serveur avant une éventuelle vente. D'autres traductions sont possibles avec des modèles autorisés, non fournis ici.

## Route audio et écouteurs

L'app demande une session audio spéciale `playAndRecord/voiceChat`, compatible réduction d'écho iOS ; pour Yoann elle autorise aussi la sortie Bluetooth A2DP et **préfère le micro intégré de l'iPhone** pour capter la personne près de celui-ci. Certains écouteurs/versions iOS peuvent choisir un autre trajet audio malgré cette préférence. Vérifier explicitement le bon microphone et le son dans les écouteurs sur l'appareil.

Sans écouteurs, l'app avertit que la traduction parlée peut être captée en retour par le microphone. L'annulation d'écho ne garantit pas la suppression parfaite de ce phénomène.

## Avant de dire « ça marche vraiment »

- IPA complète compilée pour **le commit courant** ; la réussite du simple test de syntaxe ne suffit pas.
- Sur iPhone réel : un mot « shalom » → « bonjour », puis une vraie phrase hébraïque complète traduite via le modèle HE→FR ; vérifier les paroles prononcées, le délai et le volume.
- Tester les écouteurs AirPods/câblés, bascule de sortie, permissions micro, appel entrant, verrouillage et changement d'app.
- Mesurer p50 / p95 du délai **début de parole → première syllabe française** sur une série d'échantillons ; distinguer micro, Whisper, serveur de traduction et TTS.
- Vérifier le comportement au bout d'une heure pour température, RAM, batterie, backlog, qualité, exactitude.
- Les licences d'OpenAI Whisper, Supertonic OpenRAIL-M, sherpa-onnx Apache-2.0 et des modèles MT doivent être respectées.

La PR reste volontairement en brouillon jusqu'aux tests sur matériel et à la validation de l'usage commercial.
