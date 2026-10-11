# Yoann · Translate Live (ordinateur → microphone iPhone → voix française)

## Fonction réelle

1. Ouvrir **Sarah IA → Outils → Yoann · Translate Live** ou taper / dicter **« Active Translate Live hébreu-français »** dans le chat.
2. Sur **l'ordinateur séparé**, lancer un programme TV ou une vidéo en hébreu.
3. Poser l'iPhone à proximité des haut-parleurs de l'ordinateur. L'entrée est **uniquement le microphone de l'iPhone**, et non la sortie audio du téléphone ni une API de capture interne iOS.
4. À chaque pause vocale (~0,92 s de silence configuré dans WhisperService), Whisper Base effectue la transcription hébraïque sur l'iPhone.
5. Le moteur de traduction existant `TranslationEngine` tente de convertir en français.
6. Si une vraie traduction est disponible, la voix de **Yoann M3**, générée localement via Supertonic 3, la prononce **sur les haut-parleurs de l'iPhone**.
7. Pendant la synthèse et la lecture française, le microphone reste **désactivé**. Après la fin de la lecture et un délai anti-écho de 0,55 s, l'écoute redémarre. Aucun texte généré par Yoann n'est envoyé au chat.

Le mode est isolé des appels, de la saisie vocale ordinaire et de l'assistant Sarah. La session et ses callbacks sont restaurés lorsque le mode s'arrête. Retour en arrière-plan iOS : arrêt de la capture.

## Limites explicites

- **Ce n'est pas un interprète simultané mot par mot** : l'écoute est découpée en phrases et s'interrompt pendant la lecture française. Une partie des paroles de la vidéo peut être manquée si la source continue de parler pendant que Yoann prononce la traduction. Pour écouter sans rater un passage, mettre temporairement la vidéo du PC sur pause ou utiliser l'affichage écrit.
- La capture via un microphone dépend du volume du PC, de la pièce et du bruit. Aucun accès spécial au son de Windows ni aucune connexion PC/iPhone n'est requis.
- **Important pour un futur produit commercial** : le moteur de traduction actuellement disponible est `TranslationEngine`, dont le dictionnaire local est très petit et qui fait appel à **MyMemory** via Internet pour les phrases non couvertes. L'application **ne doit pas être présentée comme une solution de traduction entièrement locale ou illimitée** dans son état actuel. Vérifier les conditions de ce service et, pour une application vendue au grand public, le remplacer par un modèle de traduction autonome et compatible commercialement ou par une API dont l'usage commercial est autorisé.
- Si le moteur ne traduit pas et renvoie simplement le texte hébreu, **ne pas le lire comme une traduction française**. Un message visible signale l'échec et l'écoute reprend.
- Le français et l'anglais sont prononcés par Supertonic 3 ; l'hébreu n'a **pas encore** de voix de sortie. La configuration **hébreu → français**, demandée pour les programmes sur ordinateur, a une voix française.
- La synthèse Supertonic 3, les modèles Whisper et leurs notices doivent être conservés dans l'IPA pour une vente conforme. Voir [VOICE_LICENSES.md](VOICE_LICENSES.md).

## Test manuel de réception nécessaire

- Compiler l'IPA complète sur GitHub Actions et lancer sur un iPhone (pas seulement parser le Swift).
- Lancer une courte émission en hébreu sur **un PC**, iPhone proche de ses haut-parleurs. Vérifier les phases **Écoute → Transcription → Traduction → Lecture de Yoann → Écoute**, sans retour de la voix française dans le micro.
- Tester la fermeture du mode, les appels entrants, Bluetooth, le passage en arrière-plan et les autorisations micro refusées.
- Tester plusieurs phrases longues de télévision, mesurer la latence, les phrases perdues et les erreurs de traduction.
- Ajouter le futur vrai traducteur neural avant de prétendre à la traduction de chaînes TV en temps réel illimitée, hors ligne et prête à la vente.
